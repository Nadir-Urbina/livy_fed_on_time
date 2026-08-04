# Livy — Fed On Time 🍼

A calm, gamified, multi-caregiver formula-feeding tracker in chunky voxel art.
One shared record of every feed — visible to every caregiver in real time —
starring **Livy**, a wise voxel granny who's raised a dozen babies and
remembers every one. Dark mode is the default and primary theme: everything is
designed to be comfortable at 3am next to a sleeping baby.

## Run it now (demo mode, zero config)

```bash
flutter pub get
cd ios && pod install && cd ..
flutter run
```

No Firebase project is required. On startup the app detects that Firebase
isn't configured and boots the built-in **demo mode**: a seeded household
(baby Olivia, caregivers You + Jordan), a week of realistic feed history,
earned badges, live streaks, a pending recommendation, a formula journal, and
sample recall notices. Every feature — the nightlight dial, logging, history &
trends, schedule approvals, the pediatrician guide, streak celebrations, the
share card, mascot switching, the paywall (simulated purchase) — is fully
demonstrable offline. Demo data persists across restarts; reset it from
*Care → Mascot & settings → Reset demo data*.

## What's inside

- **Nightlight dial** — the home screen centerpiece; a breathing ring that
  fills between feeds (cool periwinkle → amber → soft coral when due), painted
  with `CustomPainter`.
- **One-tap logging** with expandable brand/symptom/note details; synthesized
  chimes (zero audio assets) + haptics on every meaningful event.
- **Shared history & trends** — feeds/day, average amount, interval drift.
- **Approval-gated scheduling** — caregivers propose, the account holder
  approves.
- **Livy's recommendations** — non-prescriptive nudges derived from the log,
  always ending with the pediatrician disclaimer.
- **Symptom → pediatrician guide** — compiles your own notes into a shareable
  visit summary; logs a timestamped `DisclaimerAcknowledgment` on first view.
- **Formula journal, FDA recall alerts, streaks + streak-freeze, badge
  catalog with unlock celebrations, tag-team achievements, caregiver invites
  (5 seats), hard paywall, opt-in share card.**
- **All art generated via the Higgsfield MCP** in one voxel style — see
  [ASSETS.md](ASSETS.md) for the full generation log, including the mascot
  idle loop (video → 16 sprite frames) and three alternate mascot skins with
  full pose sets.

## Before shipping to the App Store

1. **Firebase** — ✅ connected to project `livy-fed-on-time`
   - `lib/firebase_options.dart` + `ios/Runner/GoogleService-Info.plist` are
     real (bundle id `com.hizwayz.livyfedontime`). Auth (Apple / Google /
     email) and Firestore are enabled; security rules live in
     `firestore.rules` (`firebase deploy --only firestore:rules`).
   - Data layout is documented in `lib/data/firestore_repository.dart`
     (households / feeds / dailyRollups / recommendations / formulaSwitches /
     users / invites). Household membership is enforced through the flat
     `memberIds` array.
   - Android still needs `android/app/google-services.json` before an
     Android release.
   - **Xcode**: open `ios/Runner.xcworkspace` once and pick the signing team —
     `Runner.entitlements` already declares push + Sign in with Apple.

2. **Feed-reminder push** — ✅ deployed (requires the Blaze plan)
   - `functions/index.js` holds two Cloud Functions: `onFeedLogged` (Firestore
     trigger) stamps a reminder marker on the household, and
     `dispatchFeedReminders` (every minute) re-validates it against the
     current latest feed + interval and pushes to every caregiver's device
     ~5 minutes before the feed is due. Stale reminders are superseded rather
     than cancelled, so schedule changes need no bookkeeping.
   - Deploy with `firebase deploy --only functions,firestore:indexes`.
   - An APNs auth key (development **and** production) must be uploaded under
     Firebase → Project Settings → Cloud Messaging. Device tokens are
     registered by `lib/services/push_service.dart` into the household's
     `fcmTokens` array and pruned automatically when a device unregisters.
   - Local notifications remain the demo-mode/offline fallback.
2. **RevenueCat**
   - Set `iosApiKey` / `androidApiKey` and (if renamed) `entitlementId` in
     `lib/services/purchase_service.dart` — pricing/products are configured in
     the RevenueCat dashboard; gating is a one-line change.
   - Hard paywall with a 7-day free trial for new subscribers; monthly
     ($4.99) + yearly ($39.99) tiers, one subscription unlocks the household
     (invited caregivers don't pay). Store products:
     `livy_fed_on_time_monthly` / `livy_fed_on_time_yearly`.
3. **FDA recall feed** — ✅ live
   - `OpenFdaRecallDataSource` pulls infant-formula recalls from the openFDA
     food-enforcement API (no key needed at this volume), keeps the last two
     years, and parses freeform `code_info` into lot-code chips. Brand
     matching keys on each logged brand's distinctive leading word ("Similac",
     "Kendamil") so generic words never false-match. Demo mode falls back to
     clearly-labeled samples when offline. Covered by
     `test/recall_service_test.dart`.
4. **Apple Watch reminders** — both the local and FCM reminders use the
   time-sensitive interruption level; iOS mirrors them to a paired watch
   automatically (the proven Flutter→Watch path; no native watch target needed).

## Insights & analytics

The Insights tab reads **daily rollups**, not raw feeds, so a household's
history can grow indefinitely without the charts getting slower or more
expensive:

- `households/{hid}/dailyRollups/{yyyy-MM-dd}` stores `count`, `totalMl`, and
  `hourCounts` / `byCaregiver` maps. Firestore increments a single bucket in
  place (`hourCounts.14: increment(1)`), so logging a feed costs one extra
  write and merges correctly across caregivers.
- `InsightsEngine.merge` overlays rollups computed from the live feed window
  on top of stored ones, so insights are correct on day one and for households
  whose history predates rollups. Covered by `test/insights_engine_test.dart`.
- Surfaces: an hour-of-day **heatmap** (night hours tinted, so you can watch
  them go quiet as the baby grows) and **Livy's weekly digest** with
  week-over-week deltas and the caregiver split.

## Project map

```
lib/
  theme/        design tokens + Material theme (Fraunces / Space Grotesk / Nunito Sans)
  models/       domain models, badge catalog, data-driven mascot registry
  data/         repository interface, local (demo) + Firestore impls, AppState
  services/     streak & recommendation engines, notifications, sounds (synthesized),
                haptics, RevenueCat, recall feed
  widgets/      mascot sprite player, celebration overlays, design-system widgets
  screens/      onboarding+paywall, home (nightlight dial), history, badges,
                care hub (recommendations, pediatrician guide, journal, recalls,
                caregivers, settings), schedule, share card
```

`flutter analyze` is clean and `flutter test` covers the demo seed, streak
engine, and the disclaimer invariant.
