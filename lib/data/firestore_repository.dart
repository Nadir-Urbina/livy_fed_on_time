import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../models/badge_catalog.dart';
import '../models/insights.dart';
import '../models/models.dart';
import 'repository.dart';

/// Real multi-caregiver sync over Firestore, with Firestore's built-in offline
/// persistence as the local cache — logging a feed never blocks on
/// connectivity; writes reconcile automatically when back online.
///
/// Layout:
///   households/{hid}                       — household doc (baby, caregivers,
///                                            schedule, streaks, mascot, badges,
///                                            disclaimer acks)
///   households/{hid}/feeds/{feedId}
///   households/{hid}/recommendations/{id}
///   households/{hid}/formulaSwitches/{id}
///   users/{uid}                            — {householdId, name}
///   invites/{code}                         — {householdId}
class FirestoreRepository implements LivyRepository {
  FirestoreRepository({required this.uid, required String displayName})
      : _name = displayName;

  final String uid;
  String _name;

  final _db = FirebaseFirestore.instance;
  final _controller = StreamController<HouseholdBundle?>.broadcast();

  HouseholdBundle? _bundle;
  String? _householdId;

  Household? _household;
  List<Feed> _feeds = const [];
  List<LivyRecommendation> _recs = const [];
  List<FormulaSwitchEntry> _switches = const [];
  StreakState _streaks = const StreakState();
  List<BadgeUnlock> _badges = const [];
  MascotState _mascot = const MascotState();
  List<DisclaimerAcknowledgment> _acks = const [];
  List<DailyRollup> _rollups = const [];

  final List<StreamSubscription> _subs = [];

  @override
  bool get isDemo => false;

  @override
  String get currentCaregiverId => uid;

  @override
  String get currentCaregiverName => _name;

  @override
  HouseholdBundle? get bundle => _bundle;

  @override
  Stream<HouseholdBundle?> get bundleStream => _controller.stream;

  DocumentReference<Map<String, dynamic>> get _hhDoc =>
      _db.collection('households').doc(_householdId);

  @override
  Future<void> init() async {
    _db.settings = const Settings(persistenceEnabled: true);
    final userDoc = await _db.collection('users').doc(uid).get();
    _householdId = userDoc.data()?['householdId'] as String?;
    final storedName = userDoc.data()?['name'] as String?;
    if (storedName != null && storedName.isNotEmpty) _name = storedName;
    if (_householdId != null) {
      _listen();
    } else {
      _controller.add(null);
    }
  }

  void _listen() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    _subs.add(_hhDoc.snapshots().listen((snap) {
      final d = snap.data();
      if (d == null) return;
      _household = Household.fromJson({...d, 'id': snap.id});
      _streaks = d['streaks'] == null
          ? const StreakState()
          : StreakState.fromJson(Map<String, dynamic>.from(d['streaks'] as Map));
      _mascot = d['mascot'] == null
          ? const MascotState()
          : MascotState.fromJson(Map<String, dynamic>.from(d['mascot'] as Map));
      _badges = (d['badges'] as List? ?? [])
          .map((e) => BadgeUnlock.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _acks = (d['disclaimerAcks'] as List? ?? [])
          .map((e) => DisclaimerAcknowledgment.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _rebuild();
    }));

    _subs.add(_hhDoc
        .collection('feeds')
        .orderBy('time', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
      _feeds = snap.docs.map((d) => Feed.fromJson(d.data())).toList();
      _rebuild();
    }));

    _subs.add(_hhDoc
        .collection('recommendations')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _recs = snap.docs.map((d) => LivyRecommendation.fromJson(d.data())).toList();
      _rebuild();
    }));

    _subs.add(_hhDoc
        .collection('formulaSwitches')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
      _switches = snap.docs.map((d) => FormulaSwitchEntry.fromJson(d.data())).toList();
      _rebuild();
    }));

    // Per-day summaries: ~180 tiny docs cover half a year of insights without
    // ever reading the full feed history.
    _subs.add(_hhDoc
        .collection('dailyRollups')
        .orderBy('day', descending: true)
        .limit(180)
        .snapshots()
        .listen((snap) {
      _rollups = snap.docs.map((d) => DailyRollup.fromJson(d.data())).toList();
      _rebuild();
    }));
  }

  void _rebuild() {
    final hh = _household;
    if (hh == null) return;
    _bundle = HouseholdBundle(
      household: hh,
      feeds: _feeds,
      recommendations: _recs,
      formulaSwitches: _switches,
      streaks: _streaks,
      badges: _badges,
      mascot: _mascot,
      disclaimerAcks: _acks,
      rollups: _rollups,
    );
    _controller.add(_bundle);
  }

  @override
  Future<void> createHousehold({
    required String caregiverName,
    required BabyProfile baby,
    required int intervalMinutes,
    required MascotState mascot,
  }) async {
    _name = caregiverName;
    final hid = const Uuid().v4();
    final code =
        'LIVY-${baby.name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '')}-${const Uuid().v4().substring(0, 4).toUpperCase()}';
    final me = Caregiver(
      id: uid,
      name: caregiverName,
      role: CaregiverRole.accountHolder,
      joinedAt: DateTime.now(),
    );
    final hh = Household(
      id: hid,
      baby: baby,
      caregivers: [me],
      schedule: FeedingSchedule(intervalMinutes: intervalMinutes),
      inviteCode: code,
      createdAt: DateTime.now(),
    );
    final batch = _db.batch();
    batch.set(_db.collection('households').doc(hid), {
      ...hh.toJson(),
      // Flat uid list mirroring `caregivers` — security rules check membership
      // against this (rules can't search arrays of maps by field).
      'memberIds': [uid],
      'streaks': const StreakState().toJson(),
      'mascot': mascot.toJson(),
      'badges': [],
      'disclaimerAcks': [],
    });
    batch.set(_db.collection('users').doc(uid), {'householdId': hid, 'name': caregiverName});
    batch.set(_db.collection('invites').doc(code), {'householdId': hid});
    await batch.commit();
    _householdId = hid;
    _listen();
    await _flushPendingToken();
  }

  /// Joins an existing household by invite code. Returns false when the code
  /// is unknown or the household is already at its 5-caregiver seat limit.
  Future<bool> joinHousehold({required String inviteCode, required String name}) async {
    final invite = await _db.collection('invites').doc(inviteCode.trim().toUpperCase()).get();
    final hid = invite.data()?['householdId'] as String?;
    if (hid == null) return false;
    final hhSnap = await _db.collection('households').doc(hid).get();
    final hh = hhSnap.data();
    if (hh == null) return false;
    final caregivers = (hh['caregivers'] as List? ?? []);
    if (caregivers.length >= Household.maxCaregivers &&
        !caregivers.any((c) => (c as Map)['id'] == uid)) {
      return false;
    }
    _name = name;
    final me = Caregiver(id: uid, name: name, role: CaregiverRole.caregiver, joinedAt: DateTime.now());
    await _db.collection('households').doc(hid).update({
      'caregivers': FieldValue.arrayUnion([me.toJson()]),
      'memberIds': FieldValue.arrayUnion([uid]),
    });
    await _db.collection('users').doc(uid).set({'householdId': hid, 'name': name});
    _householdId = hid;
    _listen();
    await _flushPendingToken();
    return true;
  }

  @override
  Future<void> logFeed(Feed feed) async {
    // Fire-and-forget so logging never blocks on connectivity; Firestore's
    // offline queue reconciles when back online.
    unawaited(_hhDoc.collection('feeds').doc(feed.id).set(feed.toJson()));
    unawaited(_bumpRollup(feed));
  }

  /// Increments the day's rollup in place. Dotted paths let Firestore bump a
  /// single hour/caregiver bucket without reading the document first, so this
  /// stays one cheap write per feed and merges correctly across caregivers.
  Future<void> _bumpRollup(Feed feed) async {
    final day = DateTime(feed.time.year, feed.time.month, feed.time.day);
    try {
      await _hhDoc.collection('dailyRollups').doc(DailyRollup.docId(day)).set({
        'day': day.millisecondsSinceEpoch,
        'count': FieldValue.increment(1),
        'totalMl': FieldValue.increment(feed.amountMl),
        'hourCounts': {'${feed.time.hour}': FieldValue.increment(1)},
        'byCaregiver': {feed.loggedById: FieldValue.increment(1)},
      }, SetOptions(merge: true));
    } catch (_) {
      // Rollups are derived data — the insights screen recomputes from feeds
      // when a day is missing, so a failed bump is never user-visible.
    }
  }

  @override
  Future<void> deleteFeed(String feedId) async {
    unawaited(_hhDoc.collection('feeds').doc(feedId).delete());
  }

  @override
  Future<void> setSchedule(FeedingSchedule schedule) async {
    unawaited(_hhDoc.update({'schedule': schedule.toJson()}));
  }

  @override
  Future<void> proposeScheduleChange(ScheduleChangeRequest request) async {
    final current = _household?.schedule.intervalMinutes ?? 180;
    unawaited(_hhDoc.update({
      'schedule': FeedingSchedule(intervalMinutes: current, pendingChange: request).toJson()
    }));
  }

  @override
  Future<void> resolveScheduleChange({required bool approve}) async {
    final pending = _household?.schedule.pendingChange;
    if (pending == null) return;
    final minutes =
        approve ? pending.proposedIntervalMinutes : _household!.schedule.intervalMinutes;
    unawaited(_hhDoc.update({'schedule': FeedingSchedule(intervalMinutes: minutes).toJson()}));
  }

  @override
  Future<void> upsertRecommendation(LivyRecommendation rec) async {
    unawaited(_hhDoc.collection('recommendations').doc(rec.id).set(rec.toJson()));
  }

  @override
  Future<void> addFormulaSwitch(FormulaSwitchEntry entry) async {
    unawaited(_hhDoc.collection('formulaSwitches').doc(entry.id).set(entry.toJson()));
  }

  @override
  Future<void> saveStreaks(StreakState streaks) async {
    unawaited(_hhDoc.update({'streaks': streaks.toJson()}));
  }

  @override
  Future<void> addBadgeUnlock(BadgeUnlock unlock) async {
    unawaited(_hhDoc.update({
      'badges': FieldValue.arrayUnion([unlock.toJson()])
    }));
  }

  @override
  Future<void> saveMascot(MascotState mascot) async {
    unawaited(_hhDoc.update({'mascot': mascot.toJson()}));
  }

  @override
  Future<void> addDisclaimerAck(DisclaimerAcknowledgment ack) async {
    unawaited(_hhDoc.update({
      'disclaimerAcks': FieldValue.arrayUnion([ack.toJson()])
    }));
  }

  @override
  Future<void> addCaregiver(Caregiver caregiver) async {
    unawaited(_hhDoc.update({
      'caregivers': FieldValue.arrayUnion([caregiver.toJson()])
    }));
  }

  @override
  Future<void> removeCaregiver(String caregiverId) async {
    final hh = _household;
    if (hh == null) return;
    unawaited(_hhDoc.update({
      'caregivers':
          hh.caregivers.where((c) => c.id != caregiverId).map((c) => c.toJson()).toList(),
      'memberIds': FieldValue.arrayRemove([caregiverId]),
    }));
  }

  @override
  Future<void> renameCurrentCaregiver(String name) async {
    _name = name;
    final hh = _household;
    if (hh == null) return;
    unawaited(_db.collection('users').doc(uid).update({'name': name}));
    unawaited(_hhDoc.update({
      'caregivers': hh.caregivers
          .map((c) => c.id == uid ? c.copyWith(name: name) : c)
          .map((c) => c.toJson())
          .toList()
    }));
  }

  /// Registers this device for server-sent feed reminders. Tokens live on
  /// the household doc so the reminder function can fan out to every
  /// caregiver. Safe to call repeatedly (arrayUnion dedupes).
  Future<void> registerFcmToken(String token) async {
    _pendingFcmToken = token;
    if (_householdId == null) return;
    unawaited(_hhDoc.update({
      'fcmTokens': FieldValue.arrayUnion([token])
    }).catchError((_) {}));
  }

  String? _pendingFcmToken;

  /// Called after a household is created/joined so a token captured pre-
  /// household still lands on the doc.
  Future<void> _flushPendingToken() async {
    final t = _pendingFcmToken;
    if (t != null && _householdId != null) {
      unawaited(_hhDoc.update({
        'fcmTokens': FieldValue.arrayUnion([t])
      }).catchError((_) {}));
    }
  }

  static Future<String?> signedInUid() async => FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _controller.close();
  }
}
