import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/badge_catalog.dart';
import '../models/insights.dart';
import '../models/models.dart';
import 'demo_seed.dart';
import 'repository.dart';

/// Local-first repository: powers demo/offline mode and doubles as the cache
/// layer semantics for the whole app. Every mutation is applied to an
/// in-memory bundle, emitted synchronously, and persisted as JSON.
class LocalRepository implements LivyRepository {
  LocalRepository({required this.isDemo, this.seedDemoData = false});

  static const _bundleKey = 'livy.bundle.v1';
  static const _caregiverIdKey = 'livy.caregiverId';
  static const _caregiverNameKey = 'livy.caregiverName';

  @override
  final bool isDemo;
  final bool seedDemoData;

  final _controller = StreamController<HouseholdBundle?>.broadcast();
  HouseholdBundle? _bundle;
  late SharedPreferences _prefs;
  String _caregiverId = '';
  String _caregiverName = '';

  @override
  String get currentCaregiverId => _caregiverId;

  @override
  String get currentCaregiverName => _caregiverName;

  @override
  HouseholdBundle? get bundle => _bundle;

  @override
  Stream<HouseholdBundle?> get bundleStream => _controller.stream;

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_bundleKey);
    if (raw != null) {
      try {
        _bundle = HouseholdBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _bundle = null;
      }
    }
    if (_bundle == null && seedDemoData) {
      _bundle = buildDemoBundle();
      await _persist();
    }
    _caregiverId = _prefs.getString(_caregiverIdKey) ??
        (_bundle != null && isDemo ? 'demo-you' : const Uuid().v4());
    _caregiverName = _prefs.getString(_caregiverNameKey) ??
        (_bundle != null && isDemo ? 'You' : 'You');
    await _prefs.setString(_caregiverIdKey, _caregiverId);
    await _prefs.setString(_caregiverNameKey, _caregiverName);
    _emit();
  }

  void _emit() => _controller.add(_bundle);

  Future<void> _persist() async {
    final b = _bundle;
    if (b == null) return;
    await _prefs.setString(_bundleKey, jsonEncode(b.toJson()));
  }

  Future<void> _mutate(HouseholdBundle Function(HouseholdBundle) fn) async {
    final b = _bundle;
    if (b == null) return;
    _bundle = fn(b);
    _emit();
    await _persist();
  }

  @override
  Future<void> createHousehold({
    required String caregiverName,
    required BabyProfile baby,
    required int intervalMinutes,
    required MascotState mascot,
  }) async {
    _caregiverName = caregiverName;
    await _prefs.setString(_caregiverNameKey, caregiverName);
    final me = Caregiver(
      id: _caregiverId,
      name: caregiverName,
      role: CaregiverRole.accountHolder,
      joinedAt: DateTime.now(),
    );
    _bundle = HouseholdBundle(
      household: Household(
        id: const Uuid().v4(),
        baby: baby,
        caregivers: [me],
        schedule: FeedingSchedule(intervalMinutes: intervalMinutes),
        inviteCode: _makeInviteCode(baby.name),
        createdAt: DateTime.now(),
      ),
      feeds: const [],
      mascot: mascot,
    );
    _emit();
    await _persist();
  }

  String _makeInviteCode(String babyName) => makeInviteCode();

  @override
  Future<void> logFeed(Feed feed) => _mutate((b) {
        final feeds = [feed, ...b.feeds]..sort((x, y) => y.time.compareTo(x.time));
        // Local mode holds the whole history in memory, so rollups are simply
        // recomputed — same shape the cloud path stores incrementally.
        return b.copyWith(feeds: feeds, rollups: InsightsEngine.fromFeeds(feeds));
      });

  @override
  Future<void> deleteFeed(String feedId) =>
      _mutate((b) => b.copyWith(feeds: b.feeds.where((f) => f.id != feedId).toList()));

  @override
  Future<void> logMeal(SolidMeal meal) => _mutate((b) {
        final meals = [meal, ...b.meals]..sort((x, y) => y.time.compareTo(x.time));
        // No rollup recompute: meals are deliberately absent from every mL
        // figure and feed count in Insights.
        return b.copyWith(meals: meals);
      });

  @override
  Future<void> deleteMeal(String mealId) =>
      _mutate((b) => b.copyWith(meals: b.meals.where((m) => m.id != mealId).toList()));

  @override
  Future<void> setSchedule(FeedingSchedule schedule) =>
      _mutate((b) => b.copyWith(household: b.household.copyWith(schedule: schedule)));

  @override
  Future<void> proposeScheduleChange(ScheduleChangeRequest request) => _mutate((b) => b.copyWith(
      household: b.household.copyWith(
          schedule: FeedingSchedule(
              intervalMinutes: b.household.schedule.intervalMinutes, pendingChange: request))));

  @override
  Future<void> resolveScheduleChange({required bool approve}) => _mutate((b) {
        final pending = b.household.schedule.pendingChange;
        if (pending == null) return b;
        return b.copyWith(
          household: b.household.copyWith(
            schedule: FeedingSchedule(
              intervalMinutes:
                  approve ? pending.proposedIntervalMinutes : b.household.schedule.intervalMinutes,
            ),
          ),
        );
      });

  @override
  Future<void> upsertRecommendation(LivyRecommendation rec) => _mutate((b) {
        final list = [...b.recommendations];
        final i = list.indexWhere((r) => r.id == rec.id);
        if (i >= 0) {
          list[i] = rec;
        } else {
          list.insert(0, rec);
        }
        return b.copyWith(recommendations: list);
      });

  @override
  Future<void> addFormulaSwitch(FormulaSwitchEntry entry) =>
      _mutate((b) => b.copyWith(formulaSwitches: [entry, ...b.formulaSwitches]));

  @override
  Future<void> saveStreaks(StreakState streaks) => _mutate((b) => b.copyWith(streaks: streaks));

  @override
  Future<void> addBadgeUnlock(BadgeUnlock unlock) => _mutate((b) =>
      b.hasBadge(unlock.badgeId) ? b : b.copyWith(badges: [...b.badges, unlock]));

  @override
  Future<void> saveMascot(MascotState mascot) => _mutate((b) => b.copyWith(mascot: mascot));

  @override
  Future<void> addDisclaimerAck(DisclaimerAcknowledgment ack) => _mutate((b) =>
      b.disclaimerAcks
              .any((a) => a.caregiverId == ack.caregiverId && a.kind == ack.kind)
          ? b
          : b.copyWith(disclaimerAcks: [...b.disclaimerAcks, ack]));

  @override
  Future<void> addCaregiver(Caregiver caregiver) => _mutate((b) {
        if (b.household.caregivers.length >= Household.maxCaregivers) return b;
        return b.copyWith(
            household:
                b.household.copyWith(caregivers: [...b.household.caregivers, caregiver]));
      });

  @override
  Future<void> removeCaregiver(String caregiverId) => _mutate((b) => b.copyWith(
      household: b.household.copyWith(
          caregivers:
              b.household.caregivers.where((c) => c.id != caregiverId).toList())));

  @override
  Future<void> updateBaby(BabyProfile baby) =>
      _mutate((b) => b.copyWith(household: b.household.copyWith(baby: baby)));

  @override
  Future<void> renameCurrentCaregiver(String name) async {
    _caregiverName = name;
    await _prefs.setString(_caregiverNameKey, name);
    await _mutate((b) => b.copyWith(
        household: b.household.copyWith(
            caregivers: b.household.caregivers
                .map((c) => c.id == _caregiverId ? c.copyWith(name: name) : c)
                .toList())));
  }

  /// Demo-only helper: wipes local state and reseeds the sample household.
  Future<void> reset() async {
    await _prefs.remove(_bundleKey);
    _bundle = seedDemoData ? buildDemoBundle() : null;
    _emit();
    await _persist();
  }

  /// Demo-only helper: wipes local state WITHOUT reseeding, so the full
  /// paywall + onboarding flow can be walked end to end.
  Future<void> clear() async {
    await _prefs.remove(_bundleKey);
    _bundle = null;
    _emit();
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
