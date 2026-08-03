import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/badge_catalog.dart';
import '../models/mascots.dart';
import '../models/insights.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/push_service.dart';
import '../services/recall_service.dart';
import '../services/recommendation_engine.dart';
import '../services/streak_engine.dart';
import 'firestore_repository.dart';
import 'local_repository.dart';
import 'repository.dart';

/// One-shot UI events (celebrations, mascot reactions) that screens listen to.
sealed class LivyEvent {}

class FeedLoggedEvent extends LivyEvent {
  FeedLoggedEvent({required this.onTime});
  final bool onTime;
}

class BadgeUnlockedEvent extends LivyEvent {
  BadgeUnlockedEvent(this.badge);
  final BadgeDef badge;
}

class TagTeamEvent extends LivyEvent {}

/// The app's single source of truth for UI. Wraps whichever repository is
/// active (local demo or Firestore), recomputes streaks/badges/recommendations
/// after each change, and emits celebration events.
class AppState extends ChangeNotifier {
  AppState({required this.repository});

  LivyRepository repository;
  late final RecallService recallService = RecallService(
      source: OpenFdaRecallDataSource(fallbackToSamples: repository.isDemo));

  HouseholdBundle? _bundle;
  StreamSubscription<HouseholdBundle?>? _sub;
  Timer? _ticker;
  bool _useMetric = true;

  final _events = StreamController<LivyEvent>.broadcast();
  Stream<LivyEvent> get events => _events.stream;

  HouseholdBundle? get bundle => _bundle;
  bool get hasHousehold => _bundle != null;
  bool get isDemo => repository.isDemo;
  bool get useMetric => _useMetric;
  String get caregiverId => repository.currentCaregiverId;
  String get caregiverName => repository.currentCaregiverName;

  bool get isAccountHolder {
    final me = _bundle?.household.caregivers
        .where((c) => c.id == caregiverId)
        .firstOrNull;
    // In demo mode you play the account holder.
    return me?.isAccountHolder ?? isDemo;
  }

  MascotDef get mascot => MascotCatalog.byId(_bundle?.mascot.mascotId ?? 'granny');
  String get mascotName => _bundle?.mascot.customName ?? mascot.defaultName;

  Future<void> init() async {
    await repository.init();
    _bundle = repository.bundle;
    _sub = repository.bundleStream.listen((b) {
      _bundle = b;
      notifyListeners();
    });
    // Re-render the dial every 30s so time-based state stays live.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    unawaited(recallService.refresh().then((_) => notifyListeners()).catchError((_) {}));
    unawaited(MascotAssetResolver.instance.warmUp().then((_) => notifyListeners()));
    _registerPushIfCloud();
    notifyListeners();
  }

  /// Server-sent reminders need an FCM token on the household (cloud mode).
  void _registerPushIfCloud() {
    final repo = repository;
    if (repo is FirestoreRepository) {
      unawaited(PushService.register(repo));
    }
  }

  /// Signs out of Firebase (used by both Sign out and Delete account) and
  /// drops back to a blank pre-auth repository so _Root returns to onboarding.
  Future<void> signOutAndReset() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    final fresh = LocalRepository(isDemo: false, seedDemoData: false);
    await swapRepository(fresh);
    await fresh.reset();
  }

  /// Swaps the backing repository (local → Firestore after a successful
  /// sign-in mid-onboarding) and re-subscribes.
  Future<void> swapRepository(LivyRepository newRepo) async {
    await _sub?.cancel();
    await repository.dispose();
    repository = newRepo;
    await repository.init();
    _bundle = repository.bundle;
    _sub = repository.bundleStream.listen((b) {
      _bundle = b;
      notifyListeners();
    });
    _registerPushIfCloud();
    notifyListeners();
  }

  // ── Dial state ─────────────────────────────────────────────────────────────

  Feed? get lastFeed => _bundle?.lastFeed;

  Duration get sinceLastFeed =>
      lastFeed == null ? Duration.zero : DateTime.now().difference(lastFeed!.time);

  DateTime? get nextFeedDue =>
      lastFeed?.time.add(_bundle?.household.schedule.interval ?? const Duration(hours: 3));

  Duration get untilNextFeed =>
      nextFeedDue == null ? Duration.zero : nextFeedDue!.difference(DateTime.now());

  bool get feedOverdue => untilNextFeed.isNegative;

  /// 0.0 (just fed) → 1.0 (due now); clamps past-due at 1.0.
  double get dialProgress {
    final interval = _bundle?.household.schedule.interval;
    if (interval == null || lastFeed == null || interval.inMinutes == 0) return 0;
    return (sinceLastFeed.inSeconds / interval.inSeconds).clamp(0.0, 1.0);
  }

  /// The mascot's live mood on the home screen.
  MascotPose get currentPose {
    if (feedOverdue) return MascotPose.concerned;
    final now = DateTime.now();
    if (now.hour >= 22 || now.hour < 6) return MascotPose.sleepy;
    return MascotPose.idle;
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> logFeed({
    required double amountMl,
    DateTime? time,
    String? formulaBrand,
    List<SymptomNote> symptoms = const [],
    String? note,
  }) async {
    final b = _bundle;
    if (b == null) return;
    final previous = b.lastFeed;
    final feed = Feed(
      id: const Uuid().v4(),
      time: time ?? DateTime.now(),
      amountMl: amountMl,
      loggedById: caregiverId,
      loggedByName: caregiverName,
      formulaBrand: formulaBrand,
      symptoms: symptoms,
      note: note,
    );
    await repository.logFeed(feed);

    final onTime = StreakEngine.feedWasOnTime(feed, previous, b.household.schedule);
    _events.add(FeedLoggedEvent(onTime: onTime));
    if (previous != null && previous.loggedById != feed.loggedById) {
      _events.add(TagTeamEvent());
    }

    await _afterHistoryChange();
    // Cloud mode: the reminder push comes from the server to every caregiver
    // ~5 minutes before the feed is due. The local notification remains the
    // offline/demo fallback so a solo device still gets nudged.
    if (repository.isDemo) {
      unawaited(NotificationService.instance.scheduleNextFeedReminder(
        lastFeedTime: feed.time,
        interval: b.household.schedule.interval,
        babyName: b.household.baby.name,
      ));
    }
  }

  Future<void> deleteFeed(String feedId) async {
    await repository.deleteFeed(feedId);
    await _afterHistoryChange();
  }

  /// Recomputes streaks/badges and lets Livy consider a recommendation.
  Future<void> _afterHistoryChange() async {
    final b = repository.bundle ?? _bundle;
    if (b == null) return;

    final result = StreakEngine.recompute(b);
    await repository.saveStreaks(result.streaks);
    for (final def in result.newBadges) {
      await repository.addBadgeUnlock(BadgeUnlock(
        badgeId: def.id,
        unlockedAt: DateTime.now(),
        unlockedBy: caregiverName,
      ));
      _events.add(BadgeUnlockedEvent(def));
    }

    final rec = RecommendationEngine.evaluate(repository.bundle ?? b);
    if (rec != null) await repository.upsertRecommendation(rec);
  }

  Future<void> setScheduleInterval(int minutes) async {
    if (!isAccountHolder) return;
    await repository.setSchedule(FeedingSchedule(intervalMinutes: minutes));
  }

  Future<void> proposeScheduleChange(int minutes) async {
    await repository.proposeScheduleChange(ScheduleChangeRequest(
      proposedIntervalMinutes: minutes,
      proposedById: caregiverId,
      proposedByName: caregiverName,
      proposedAt: DateTime.now(),
    ));
  }

  Future<void> resolveScheduleChange({required bool approve}) =>
      repository.resolveScheduleChange(approve: approve);

  Future<void> dismissRecommendation(LivyRecommendation rec) =>
      repository.upsertRecommendation(rec.copyWith(dismissed: true));

  Future<void> actOnRecommendation(LivyRecommendation rec) =>
      repository.upsertRecommendation(rec.copyWith(actedOn: true, dismissed: true));

  Future<void> addFormulaSwitch(FormulaSwitchEntry entry) =>
      repository.addFormulaSwitch(entry);

  Future<void> setMascot({required String mascotId, String? customName}) =>
      repository.saveMascot(MascotState(mascotId: mascotId, customName: customName));

  Future<void> acknowledgeDisclaimer() => repository.addDisclaimerAck(
      DisclaimerAcknowledgment(caregiverId: caregiverId, acknowledgedAt: DateTime.now()));

  bool get hasAcknowledgedDisclaimer =>
      _bundle?.disclaimerAcks.any((a) => a.caregiverId == caregiverId) ?? false;

  Future<void> createHousehold({
    required String caregiverName,
    required BabyProfile baby,
    required int intervalMinutes,
    required MascotState mascot,
  }) async {
    await repository.createHousehold(
      caregiverName: caregiverName,
      baby: baby,
      intervalMinutes: intervalMinutes,
      mascot: mascot,
    );
    notifyListeners();
  }

  /// Demo-only: add a pretend caregiver so invite flows are demonstrable.
  Future<void> addDemoCaregiver(String name) async {
    await repository.addCaregiver(Caregiver(
      id: const Uuid().v4(),
      name: name,
      role: CaregiverRole.caregiver,
      joinedAt: DateTime.now(),
    ));
  }

  Future<void> removeCaregiver(String id) => repository.removeCaregiver(id);

  void toggleUnits() {
    _useMetric = !_useMetric;
    notifyListeners();
  }

  String formatAmount(double ml) => _useMetric
      ? '${ml.round()} mL'
      : '${(ml / 29.5735).toStringAsFixed(1)} oz';

  // ── Trends ─────────────────────────────────────────────────────────────────

  /// Feeds-per-day for the last [days], oldest first: [(day, count, avgMl)].
  List<({DateTime day, int count, double avgMl})> dailyTrend({int days = 7}) {
    final b = _bundle;
    if (b == null) return const [];
    final today = StreakEngine.dayOf(DateTime.now());
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      final feeds = b.feeds.where((f) => StreakEngine.dayOf(f.time) == day).toList();
      final avg = feeds.isEmpty
          ? 0.0
          : feeds.map((f) => f.amountMl).reduce((a, c) => a + c) / feeds.length;
      return (day: day, count: feeds.length, avgMl: avg);
    });
  }

  /// Average gap between feeds per day — makes interval drift visible.
  List<({DateTime day, double avgGapMinutes})> intervalTrend({int days = 7}) {
    final b = _bundle;
    if (b == null) return const [];
    final today = StreakEngine.dayOf(DateTime.now());
    return List.generate(days, (i) {
      final day = today.subtract(Duration(days: days - 1 - i));
      final feeds = b.feeds.where((f) => StreakEngine.dayOf(f.time) == day).toList()
        ..sort((a, c) => a.time.compareTo(c.time));
      final gaps = <int>[];
      for (var k = 1; k < feeds.length; k++) {
        final g = feeds[k].time.difference(feeds[k - 1].time).inMinutes;
        if (g > 30 && g < 8 * 60) gaps.add(g);
      }
      final avg = gaps.isEmpty ? 0.0 : gaps.reduce((a, c) => a + c) / gaps.length;
      return (day: day, avgGapMinutes: avg);
    });
  }

  // ── Insights ───────────────────────────────────────────────────────────────

  /// Stored rollups (deep history) merged with rollups computed from the live
  /// feed window, so insights are correct on day one and for households whose
  /// history predates rollups.
  List<DailyRollup> get rollups {
    final b = _bundle;
    if (b == null) return const [];
    return InsightsEngine.merge(b.rollups, b.feeds);
  }

  /// Last [days] days, oldest first, with empty days included.
  List<DailyRollup> rollupWindow({int days = 21}) =>
      InsightsEngine.window(rollups, days: days);

  WeeklyDigest? get weeklyDigest =>
      _bundle == null ? null : InsightsEngine.digest(rollups, _bundle!.feeds);

  /// Display name for a caregiver id (falls back to a friendly label).
  String caregiverNameFor(String id) {
    final c =
        _bundle?.household.caregivers.where((c) => c.id == id).firstOrNull;
    return c?.name ?? 'Someone';
  }

  Set<String> get loggedBrands => {
        ...?_bundle?.feeds.map((f) => f.formulaBrand).whereType<String>(),
        ...?_bundle?.formulaSwitches.map((s) => s.brand),
      };

  List<RecallNotice> get relevantRecalls => recallService.relevantTo(loggedBrands);

  Future<void> refreshRecalls() async {
    await recallService.refresh();
    notifyListeners();
  }

  Future<void> resetDemo() async {
    final repo = repository;
    if (repo is LocalRepository) {
      await repo.reset();
      notifyListeners();
    }
  }

  /// Demo-only: clears the household entirely so the hard paywall and the
  /// full onboarding flow can be experienced end to end.
  Future<void> replayOnboarding() async {
    final repo = repository;
    if (repo is LocalRepository) {
      await repo.clear();
      _bundle = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _events.close();
    super.dispose();
  }
}
