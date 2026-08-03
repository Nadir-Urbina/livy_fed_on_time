/**
 * Livy — Fed On Time · Cloud Functions
 *
 * Feed reminders: every caregiver's phone gets an FCM push ~5 minutes before
 * the next scheduled feed.
 *
 * Design: when a feed is logged, `onFeedLogged` stamps the household with a
 * `reminder` marker {dueMs, sendAtMs, sent}. A once-per-minute dispatcher
 * (`dispatchFeedReminders`) picks up due markers and re-validates against the
 * household's CURRENT latest feed + interval before sending — so a newer feed
 * or an approved schedule change silently supersedes a stale reminder without
 * any cancellation bookkeeping.
 *
 * Cost: ~2 writes per feed + 43k tiny scheduler runs/month — comfortably
 * inside the Blaze free tier at early scale.
 */

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");

initializeApp();

const REMINDER_LEAD_MS = 5 * 60 * 1000; // notify 5 minutes before due
const STALE_TOLERANCE_MS = 90 * 1000; // reminder vs. recomputed due drift
const EXPIRY_MS = 15 * 60 * 1000; // too old to be useful — drop silently

/** Stamp/refresh the household's reminder marker whenever a feed is logged. */
exports.onFeedLogged = onDocumentCreated(
    "households/{hid}/feeds/{feedId}",
    async (event) => {
      const feed = event.data && event.data.data();
      if (!feed || typeof feed.time !== "number") return;

      const hhRef = getFirestore().doc(`households/${event.params.hid}`);
      const hhSnap = await hhRef.get();
      const hh = hhSnap.data();
      if (!hh) return;

      const intervalMin =
        (hh.schedule && hh.schedule.intervalMinutes) || 180;
      const dueMs = feed.time + intervalMin * 60 * 1000;
      const sendAtMs = dueMs - REMINDER_LEAD_MS;
      if (sendAtMs <= Date.now()) return; // back-dated log — nothing to remind

      await hhRef.update({
        reminder: {
          feedId: event.params.feedId,
          dueMs: dueMs,
          sendAtMs: sendAtMs,
          sent: false,
        },
      });
    });

/** Once a minute: send every due, still-valid reminder. */
exports.dispatchFeedReminders = onSchedule("every 1 minutes", async () => {
  const db = getFirestore();
  const now = Date.now();

  const due = await db
      .collection("households")
      .where("reminder.sent", "==", false)
      .where("reminder.sendAtMs", "<=", now)
      .limit(200)
      .get();
  if (due.empty) return;

  for (const doc of due.docs) {
    const hh = doc.data();
    const reminder = hh.reminder || {};
    try {
      // Re-validate against current truth: latest feed + current interval.
      const lastFeedSnap = await doc.ref
          .collection("feeds")
          .orderBy("time", "desc")
          .limit(1)
          .get();
      if (lastFeedSnap.empty) {
        await doc.ref.update({"reminder.sent": true});
        continue;
      }
      const last = lastFeedSnap.docs[0].data();
      const intervalMin =
        (hh.schedule && hh.schedule.intervalMinutes) || 180;
      const currentDueMs = last.time + intervalMin * 60 * 1000;

      if (Math.abs(currentDueMs - reminder.dueMs) > STALE_TOLERANCE_MS) {
        // A newer feed or schedule change moved the target — resync the
        // marker to the new due time instead of sending a stale reminder.
        const sendAtMs = currentDueMs - REMINDER_LEAD_MS;
        await doc.ref.update({
          reminder: {
            feedId: lastFeedSnap.docs[0].id,
            dueMs: currentDueMs,
            sendAtMs: sendAtMs,
            sent: sendAtMs <= now,
          },
        });
        continue;
      }

      if (now - reminder.sendAtMs > EXPIRY_MS) {
        await doc.ref.update({"reminder.sent": true});
        continue;
      }

      const tokens = Array.isArray(hh.fcmTokens) ? hh.fcmTokens : [];
      if (tokens.length === 0) {
        await doc.ref.update({"reminder.sent": true});
        continue;
      }

      const babyName = (hh.baby && hh.baby.name) || "Baby";
      const res = await getMessaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: "Almost bottle time 🍼",
          body: `${babyName}'s next feed is in about 5 minutes. ` +
            "Livy has the kettle on.",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              "interruption-level": "time-sensitive",
            },
          },
        },
      });

      // Prune tokens for uninstalled/expired devices.
      const dead = [];
      res.responses.forEach((r, i) => {
        const code = r.error && r.error.code;
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token" ||
            code === "messaging/invalid-argument") {
          dead.push(tokens[i]);
        }
      });
      const update = {"reminder.sent": true};
      if (dead.length > 0) {
        update.fcmTokens = FieldValue.arrayRemove(...dead);
      }
      await doc.ref.update(update);
      logger.info(
          `Reminder sent for household ${doc.id}: ` +
          `${res.successCount} ok, ${res.failureCount} failed`);
    } catch (err) {
      logger.error(`Reminder dispatch failed for ${doc.id}`, err);
    }
  }
});

/**
 * Full account deletion (App Store guideline 5.1.1(v)).
 *
 * Policy: a plain caregiver leaving just frees their seat; the ACCOUNT HOLDER
 * (or the last remaining member) deleting their account deletes the entire
 * household — their subscription funds it, and the app's confirm dialog spells
 * this out before calling here.
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const db = getFirestore();

  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  const hid = userSnap.exists ? userSnap.data().householdId : null;

  if (hid) {
    const hhRef = db.doc(`households/${hid}`);
    const hhSnap = await hhRef.get();
    if (hhSnap.exists) {
      const hh = hhSnap.data();
      const caregivers = hh.caregivers || [];
      const me = caregivers.find((c) => c.id === uid);
      const isHolder = !!me && me.role === "accountHolder";
      const others = (hh.memberIds || []).filter((m) => m !== uid);

      if (isHolder || others.length === 0) {
        if (hh.inviteCode) {
          await db.doc(`invites/${hh.inviteCode}`).delete().catch(() => {});
        }
        // Removes the household doc AND all subcollections (feeds, rollups,
        // recommendations, formulaSwitches).
        await db.recursiveDelete(hhRef);
        logger.info(`deleteAccount: household ${hid} deleted by ${uid}`);
      } else {
        await hhRef.update({
          caregivers: caregivers.filter((c) => c.id !== uid),
          memberIds: FieldValue.arrayRemove(uid),
        });
        logger.info(`deleteAccount: ${uid} left household ${hid}`);
      }
    }
  }

  await userRef.delete().catch(() => {});
  await getAuth().deleteUser(uid);
  return {ok: true};
});
