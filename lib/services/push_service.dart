import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/firestore_repository.dart';

/// FCM registration for server-sent feed reminders (Firebase mode only).
/// The device token is stored on the household doc (`fcmTokens` array); the
/// `dispatchFeedReminders` Cloud Function fans out to every caregiver device
/// ~5 minutes before the next scheduled feed.
class PushService {
  PushService._();

  static StreamSubscription<String>? _refreshSub;

  static Future<void> register(FirestoreRepository repo) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Same APNs prompt the onboarding notifications page triggers — if the
      // user already granted it there, this resolves silently.
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await repo.registerFcmToken(token);

      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh
          .listen((t) => repo.registerFcmToken(t), onError: (_) {});
    } catch (_) {
      // No APNs on simulators / permission denied — reminders simply stay
      // local-only for this device. Never let push break the app.
    }
  }
}
