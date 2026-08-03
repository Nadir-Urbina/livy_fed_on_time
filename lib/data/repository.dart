import '../models/badge_catalog.dart';
import '../models/insights.dart';
import '../models/models.dart';

/// One consistent snapshot of everything a household shares. Both the local
/// (demo/offline) and Firestore repositories emit these, so the entire UI is
/// backend-agnostic.
class HouseholdBundle {
  HouseholdBundle({
    required this.household,
    required this.feeds,
    this.recommendations = const [],
    this.formulaSwitches = const [],
    this.streaks = const StreakState(),
    this.badges = const [],
    this.mascot = const MascotState(),
    this.disclaimerAcks = const [],
    this.rollups = const [],
  });

  final Household household;

  /// Sorted newest-first.
  final List<Feed> feeds;
  final List<LivyRecommendation> recommendations;
  final List<FormulaSwitchEntry> formulaSwitches;
  final StreakState streaks;
  final List<BadgeUnlock> badges;
  final MascotState mascot;
  final List<DisclaimerAcknowledgment> disclaimerAcks;

  /// Stored per-day summaries covering history beyond the live feed window.
  /// Merge with [feeds] via `InsightsEngine.merge` before charting.
  final List<DailyRollup> rollups;

  Feed? get lastFeed => feeds.isEmpty ? null : feeds.first;

  bool hasBadge(String badgeId) => badges.any((b) => b.badgeId == badgeId);

  Map<String, dynamic> toJson() => {
        'household': household.toJson(),
        'feeds': feeds.map((f) => f.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'formulaSwitches': formulaSwitches.map((f) => f.toJson()).toList(),
        'streaks': streaks.toJson(),
        'badges': badges.map((b) => b.toJson()).toList(),
        'mascot': mascot.toJson(),
        'disclaimerAcks': disclaimerAcks.map((d) => d.toJson()).toList(),
        'rollups': rollups.map((r) => r.toJson()).toList(),
      };

  factory HouseholdBundle.fromJson(Map<String, dynamic> j) => HouseholdBundle(
        household: Household.fromJson(Map<String, dynamic>.from(j['household'] as Map)),
        feeds: _list(j['feeds']).map(Feed.fromJson).toList()
          ..sort((a, b) => b.time.compareTo(a.time)),
        recommendations: _list(j['recommendations']).map(LivyRecommendation.fromJson).toList(),
        formulaSwitches: _list(j['formulaSwitches']).map(FormulaSwitchEntry.fromJson).toList(),
        streaks: j['streaks'] == null
            ? const StreakState()
            : StreakState.fromJson(Map<String, dynamic>.from(j['streaks'] as Map)),
        badges: _list(j['badges']).map(BadgeUnlock.fromJson).toList(),
        mascot: j['mascot'] == null
            ? const MascotState()
            : MascotState.fromJson(Map<String, dynamic>.from(j['mascot'] as Map)),
        disclaimerAcks: _list(j['disclaimerAcks']).map(DisclaimerAcknowledgment.fromJson).toList(),
        rollups: _list(j['rollups']).map(DailyRollup.fromJson).toList(),
      );

  static Iterable<Map<String, dynamic>> _list(dynamic v) =>
      (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map));

  HouseholdBundle copyWith({
    Household? household,
    List<Feed>? feeds,
    List<LivyRecommendation>? recommendations,
    List<FormulaSwitchEntry>? formulaSwitches,
    StreakState? streaks,
    List<BadgeUnlock>? badges,
    MascotState? mascot,
    List<DisclaimerAcknowledgment>? disclaimerAcks,
    List<DailyRollup>? rollups,
  }) =>
      HouseholdBundle(
        household: household ?? this.household,
        feeds: feeds ?? this.feeds,
        recommendations: recommendations ?? this.recommendations,
        formulaSwitches: formulaSwitches ?? this.formulaSwitches,
        streaks: streaks ?? this.streaks,
        badges: badges ?? this.badges,
        mascot: mascot ?? this.mascot,
        disclaimerAcks: disclaimerAcks ?? this.disclaimerAcks,
        rollups: rollups ?? this.rollups,
      );
}

/// Backend abstraction. `LocalRepository` powers demo/offline mode;
/// `FirestoreRepository` powers real multi-caregiver sync. The UI only ever
/// talks to this interface (through AppState).
abstract class LivyRepository {
  /// The caregiver using this device.
  String get currentCaregiverId;
  String get currentCaregiverName;

  bool get isDemo;

  Future<void> init();

  Stream<HouseholdBundle?> get bundleStream;
  HouseholdBundle? get bundle;

  Future<void> createHousehold({
    required String caregiverName,
    required BabyProfile baby,
    required int intervalMinutes,
    required MascotState mascot,
  });

  Future<void> logFeed(Feed feed);
  Future<void> deleteFeed(String feedId);

  Future<void> setSchedule(FeedingSchedule schedule);
  Future<void> proposeScheduleChange(ScheduleChangeRequest request);
  Future<void> resolveScheduleChange({required bool approve});

  Future<void> upsertRecommendation(LivyRecommendation rec);
  Future<void> addFormulaSwitch(FormulaSwitchEntry entry);
  Future<void> saveStreaks(StreakState streaks);
  Future<void> addBadgeUnlock(BadgeUnlock unlock);
  Future<void> saveMascot(MascotState mascot);
  Future<void> addDisclaimerAck(DisclaimerAcknowledgment ack);

  Future<void> addCaregiver(Caregiver caregiver);
  Future<void> removeCaregiver(String caregiverId);
  Future<void> renameCurrentCaregiver(String name);

  Future<void> dispose();
}
