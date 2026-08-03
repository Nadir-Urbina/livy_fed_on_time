import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Feed reminders on iPhone — and, when a paired Apple Watch is present, iOS
/// automatically mirrors these notifications to the wrist (the proven
/// Flutter → Watch notification path; no bridged native Watch app needed).
///
/// FCM (push fan-out between caregivers) initializes only when Firebase is
/// configured; local scheduling works everywhere including demo mode.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  static const _feedReminderId = 1001;
  static const _streakRiskId = 1002;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (_) {
      // Fall back to the package default; times may shift but never crash.
    }
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(iOS: ios, android: android),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      _permissionGranted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      _permissionGranted = await android.requestNotificationsPermission() ?? false;
    }
    return _permissionGranted;
  }

  /// Schedules the next-feed reminder relative to the last feed. Re-invoked on
  /// every log, so the reminder always tracks the live schedule.
  Future<void> scheduleNextFeedReminder({
    required DateTime lastFeedTime,
    required Duration interval,
    required String babyName,
  }) async {
    await init();
    await _plugin.cancel(id: _feedReminderId);
    final due = lastFeedTime.add(interval);
    if (due.isBefore(DateTime.now())) return;
    await _schedule(
      id: _feedReminderId,
      title: 'Almost bottle time 🍼',
      body: "$babyName's next feed is due about now. Livy has the kettle on.",
      when: due,
    );
  }

  Future<void> scheduleStreakRiskReminder({
    required DateTime dueBy,
    required int streakDays,
  }) async {
    await init();
    await _plugin.cancel(id: _streakRiskId);
    if (dueBy.isBefore(DateTime.now())) return;
    await _schedule(
      id: _streakRiskId,
      title: 'Your $streakDays-day streak is cozy but nervous',
      body: 'One logged feed keeps it warm. Livy believes in you.',
      when: dueBy,
    );
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      android: AndroidNotificationDetails(
        'livy_reminders',
        'Feed reminders',
        channelDescription: 'Reminders for upcoming feeds and streaks',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Scheduling can fail without notification entitlements (e.g. some
      // simulators) — degrade silently; the dial is the primary surface.
    }
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
