import 'package:flutter/foundation.dart';

/// All Livy domain models. Hand-rolled JSON so the same maps serialize to
/// Firestore documents and to the local demo-mode cache.

DateTime _dt(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  // Firestore Timestamp exposes toDate() — avoid importing cloud_firestore here.
  try {
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}

int _ts(DateTime d) => d.millisecondsSinceEpoch;

enum CaregiverRole { accountHolder, caregiver }

@immutable
class Caregiver {
  const Caregiver({
    required this.id,
    required this.name,
    required this.role,
    this.joinedAt,
    this.invitePending = false,
  });

  final String id;
  final String name;
  final CaregiverRole role;
  final DateTime? joinedAt;
  final bool invitePending;

  bool get isAccountHolder => role == CaregiverRole.accountHolder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'joinedAt': joinedAt == null ? null : _ts(joinedAt!),
        'invitePending': invitePending,
      };

  factory Caregiver.fromJson(Map<String, dynamic> j) => Caregiver(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Caregiver',
        role: CaregiverRole.values.asNameMap()[j['role']] ?? CaregiverRole.caregiver,
        joinedAt: j['joinedAt'] == null ? null : _dt(j['joinedAt']),
        invitePending: j['invitePending'] as bool? ?? false,
      );

  Caregiver copyWith({String? name, CaregiverRole? role, bool? invitePending}) => Caregiver(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        joinedAt: joinedAt,
        invitePending: invitePending ?? this.invitePending,
      );
}

@immutable
class BabyProfile {
  const BabyProfile({required this.name, required this.birthDate, this.photoPath});

  final String name;
  final DateTime birthDate;
  final String? photoPath;

  int get ageInDays => DateTime.now().difference(birthDate).inDays;
  int get ageInWeeks => ageInDays ~/ 7;
  int get ageInMonths => (ageInDays / 30.44).floor();

  String get ageLabel {
    if (ageInDays < 14) return '$ageInDays days old';
    if (ageInMonths < 3) return '$ageInWeeks weeks old';
    return '$ageInMonths months old';
  }

  Map<String, dynamic> toJson() =>
      {'name': name, 'birthDate': _ts(birthDate), 'photoPath': photoPath};

  factory BabyProfile.fromJson(Map<String, dynamic> j) => BabyProfile(
        name: j['name'] as String? ?? 'Baby',
        birthDate: _dt(j['birthDate']),
        photoPath: j['photoPath'] as String?,
      );
}

enum SymptomKind { poop, gas, spitUp, fussiness, reflux, mood, other }

extension SymptomKindLabel on SymptomKind {
  String get label => switch (this) {
        SymptomKind.poop => 'Poop',
        SymptomKind.gas => 'Gas',
        SymptomKind.spitUp => 'Spit-up',
        SymptomKind.fussiness => 'Fussiness',
        SymptomKind.reflux => 'Reflux signs',
        SymptomKind.mood => 'Mood',
        SymptomKind.other => 'Other',
      };
}

@immutable
class SymptomNote {
  const SymptomNote({required this.kind, this.note = ''});
  final SymptomKind kind;
  final String note;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'note': note};
  factory SymptomNote.fromJson(Map<String, dynamic> j) => SymptomNote(
        kind: SymptomKind.values.asNameMap()[j['kind']] ?? SymptomKind.other,
        note: j['note'] as String? ?? '',
      );
}

@immutable
class Feed {
  const Feed({
    required this.id,
    required this.time,
    required this.amountMl,
    required this.loggedById,
    required this.loggedByName,
    this.formulaBrand,
    this.symptoms = const [],
    this.note,
  });

  final String id;
  final DateTime time;
  final double amountMl;
  final String loggedById;
  final String loggedByName;
  final String? formulaBrand;
  final List<SymptomNote> symptoms;
  final String? note;

  double get amountOz => amountMl / 29.5735;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': _ts(time),
        'amountMl': amountMl,
        'loggedById': loggedById,
        'loggedByName': loggedByName,
        'formulaBrand': formulaBrand,
        'symptoms': symptoms.map((s) => s.toJson()).toList(),
        'note': note,
      };

  factory Feed.fromJson(Map<String, dynamic> j) => Feed(
        id: j['id'] as String,
        time: _dt(j['time']),
        amountMl: (j['amountMl'] as num?)?.toDouble() ?? 0,
        loggedById: j['loggedById'] as String? ?? '',
        loggedByName: j['loggedByName'] as String? ?? 'Someone',
        formulaBrand: j['formulaBrand'] as String?,
        symptoms: (j['symptoms'] as List? ?? [])
            .map((e) => SymptomNote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        note: j['note'] as String?,
      );
}

enum ScheduleChangeState { none, pending, approved, declined }

@immutable
class ScheduleChangeRequest {
  const ScheduleChangeRequest({
    required this.proposedIntervalMinutes,
    required this.proposedById,
    required this.proposedByName,
    required this.proposedAt,
    this.state = ScheduleChangeState.pending,
  });

  final int proposedIntervalMinutes;
  final String proposedById;
  final String proposedByName;
  final DateTime proposedAt;
  final ScheduleChangeState state;

  Map<String, dynamic> toJson() => {
        'proposedIntervalMinutes': proposedIntervalMinutes,
        'proposedById': proposedById,
        'proposedByName': proposedByName,
        'proposedAt': _ts(proposedAt),
        'state': state.name,
      };

  factory ScheduleChangeRequest.fromJson(Map<String, dynamic> j) => ScheduleChangeRequest(
        proposedIntervalMinutes: j['proposedIntervalMinutes'] as int? ?? 180,
        proposedById: j['proposedById'] as String? ?? '',
        proposedByName: j['proposedByName'] as String? ?? 'A caregiver',
        proposedAt: _dt(j['proposedAt']),
        state: ScheduleChangeState.values.asNameMap()[j['state']] ?? ScheduleChangeState.pending,
      );
}

@immutable
class FeedingSchedule {
  const FeedingSchedule({required this.intervalMinutes, this.pendingChange});

  final int intervalMinutes;
  final ScheduleChangeRequest? pendingChange;

  Duration get interval => Duration(minutes: intervalMinutes);

  String get intervalLabel {
    final h = intervalMinutes ~/ 60, m = intervalMinutes % 60;
    if (m == 0) return 'every ${h}h';
    if (h == 0) return 'every ${m}m';
    return 'every ${h}h ${m}m';
  }

  Map<String, dynamic> toJson() =>
      {'intervalMinutes': intervalMinutes, 'pendingChange': pendingChange?.toJson()};

  factory FeedingSchedule.fromJson(Map<String, dynamic> j) => FeedingSchedule(
        intervalMinutes: j['intervalMinutes'] as int? ?? 180,
        pendingChange: j['pendingChange'] == null
            ? null
            : ScheduleChangeRequest.fromJson(Map<String, dynamic>.from(j['pendingChange'] as Map)),
      );
}

enum RecommendationKind { intervalDrift, amountTrend, consistencyPraise, ageMilestone }

@immutable
class LivyRecommendation {
  const LivyRecommendation({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.dismissed = false,
    this.actedOn = false,
  });

  final String id;
  final RecommendationKind kind;
  final String text;
  final DateTime createdAt;
  final bool dismissed;
  final bool actedOn;

  static const String disclaimer =
      'We recommend checking with your pediatrician before making changes.';

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'createdAt': _ts(createdAt),
        'dismissed': dismissed,
        'actedOn': actedOn,
      };

  factory LivyRecommendation.fromJson(Map<String, dynamic> j) => LivyRecommendation(
        id: j['id'] as String,
        kind: RecommendationKind.values.asNameMap()[j['kind']] ?? RecommendationKind.amountTrend,
        text: j['text'] as String? ?? '',
        createdAt: _dt(j['createdAt']),
        dismissed: j['dismissed'] as bool? ?? false,
        actedOn: j['actedOn'] as bool? ?? false,
      );

  LivyRecommendation copyWith({bool? dismissed, bool? actedOn}) => LivyRecommendation(
        id: id,
        kind: kind,
        text: text,
        createdAt: createdAt,
        dismissed: dismissed ?? this.dismissed,
        actedOn: actedOn ?? this.actedOn,
      );
}

@immutable
class FormulaSwitchEntry {
  const FormulaSwitchEntry({
    required this.id,
    required this.date,
    required this.brand,
    this.reason = '',
    this.response = '',
  });

  final String id;
  final DateTime date;
  final String brand;
  final String reason;
  final String response;

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': _ts(date), 'brand': brand, 'reason': reason, 'response': response};

  factory FormulaSwitchEntry.fromJson(Map<String, dynamic> j) => FormulaSwitchEntry(
        id: j['id'] as String,
        date: _dt(j['date']),
        brand: j['brand'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        response: j['response'] as String? ?? '',
      );
}

@immutable
class RecallNotice {
  const RecallNotice({
    required this.id,
    required this.brand,
    required this.title,
    required this.summary,
    required this.publishedAt,
    this.lotCodes = const [],
    this.link,
  });

  final String id;
  final String brand;
  final String title;
  final String summary;
  final DateTime publishedAt;
  final List<String> lotCodes;
  final String? link;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'title': title,
        'summary': summary,
        'publishedAt': _ts(publishedAt),
        'lotCodes': lotCodes,
        'link': link,
      };

  factory RecallNotice.fromJson(Map<String, dynamic> j) => RecallNotice(
        id: j['id'] as String,
        brand: j['brand'] as String? ?? '',
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        publishedAt: _dt(j['publishedAt']),
        lotCodes: (j['lotCodes'] as List? ?? []).cast<String>(),
        link: j['link'] as String?,
      );
}

/// The three celebrated tracks: feeding on schedule, logging every feed,
/// and tag-team caregiver handoffs.
@immutable
class StreakState {
  const StreakState({
    this.onTimeStreakDays = 0,
    this.loggingStreakDays = 0,
    this.tagTeamStreakDays = 0,
    this.bestOnTimeStreak = 0,
    this.bestLoggingStreak = 0,
    this.bestTagTeamStreak = 0,
    this.freezeAvailable = true,
    this.freezeUsedAt,
    this.lastUpdatedDay,
  });

  final int onTimeStreakDays;
  final int loggingStreakDays;
  final int tagTeamStreakDays;
  final int bestOnTimeStreak;
  final int bestLoggingStreak;
  final int bestTagTeamStreak;
  final bool freezeAvailable;
  final DateTime? freezeUsedAt;
  final DateTime? lastUpdatedDay;

  Map<String, dynamic> toJson() => {
        'onTimeStreakDays': onTimeStreakDays,
        'loggingStreakDays': loggingStreakDays,
        'tagTeamStreakDays': tagTeamStreakDays,
        'bestOnTimeStreak': bestOnTimeStreak,
        'bestLoggingStreak': bestLoggingStreak,
        'bestTagTeamStreak': bestTagTeamStreak,
        'freezeAvailable': freezeAvailable,
        'freezeUsedAt': freezeUsedAt == null ? null : _ts(freezeUsedAt!),
        'lastUpdatedDay': lastUpdatedDay == null ? null : _ts(lastUpdatedDay!),
      };

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
        onTimeStreakDays: j['onTimeStreakDays'] as int? ?? 0,
        loggingStreakDays: j['loggingStreakDays'] as int? ?? 0,
        tagTeamStreakDays: j['tagTeamStreakDays'] as int? ?? 0,
        bestOnTimeStreak: j['bestOnTimeStreak'] as int? ?? 0,
        bestLoggingStreak: j['bestLoggingStreak'] as int? ?? 0,
        bestTagTeamStreak: j['bestTagTeamStreak'] as int? ?? 0,
        freezeAvailable: j['freezeAvailable'] as bool? ?? true,
        freezeUsedAt: j['freezeUsedAt'] == null ? null : _dt(j['freezeUsedAt']),
        lastUpdatedDay: j['lastUpdatedDay'] == null ? null : _dt(j['lastUpdatedDay']),
      );

  StreakState copyWith({
    int? onTimeStreakDays,
    int? loggingStreakDays,
    int? tagTeamStreakDays,
    int? bestOnTimeStreak,
    int? bestLoggingStreak,
    int? bestTagTeamStreak,
    bool? freezeAvailable,
    DateTime? freezeUsedAt,
    DateTime? lastUpdatedDay,
  }) =>
      StreakState(
        onTimeStreakDays: onTimeStreakDays ?? this.onTimeStreakDays,
        loggingStreakDays: loggingStreakDays ?? this.loggingStreakDays,
        tagTeamStreakDays: tagTeamStreakDays ?? this.tagTeamStreakDays,
        bestOnTimeStreak: bestOnTimeStreak ?? this.bestOnTimeStreak,
        bestLoggingStreak: bestLoggingStreak ?? this.bestLoggingStreak,
        bestTagTeamStreak: bestTagTeamStreak ?? this.bestTagTeamStreak,
        freezeAvailable: freezeAvailable ?? this.freezeAvailable,
        freezeUsedAt: freezeUsedAt ?? this.freezeUsedAt,
        lastUpdatedDay: lastUpdatedDay ?? this.lastUpdatedDay,
      );
}

@immutable
class MascotState {
  const MascotState({this.mascotId = 'granny', this.customName});

  final String mascotId;
  final String? customName;

  Map<String, dynamic> toJson() => {'mascotId': mascotId, 'customName': customName};

  factory MascotState.fromJson(Map<String, dynamic> j) => MascotState(
        mascotId: j['mascotId'] as String? ?? 'granny',
        customName: j['customName'] as String?,
      );
}

/// Recorded the first time a caregiver views pediatrician-guide content.
@immutable
class DisclaimerAcknowledgment {
  const DisclaimerAcknowledgment({required this.caregiverId, required this.acknowledgedAt});

  final String caregiverId;
  final DateTime acknowledgedAt;

  Map<String, dynamic> toJson() =>
      {'caregiverId': caregiverId, 'acknowledgedAt': _ts(acknowledgedAt)};

  factory DisclaimerAcknowledgment.fromJson(Map<String, dynamic> j) => DisclaimerAcknowledgment(
        caregiverId: j['caregiverId'] as String? ?? '',
        acknowledgedAt: _dt(j['acknowledgedAt']),
      );
}

@immutable
class Household {
  const Household({
    required this.id,
    required this.baby,
    required this.caregivers,
    required this.schedule,
    this.inviteCode,
    this.createdAt,
  });

  final String id;
  final BabyProfile baby;
  final List<Caregiver> caregivers;
  final FeedingSchedule schedule;
  final String? inviteCode;
  final DateTime? createdAt;

  static const int maxCaregivers = 5;

  Map<String, dynamic> toJson() => {
        'id': id,
        'baby': baby.toJson(),
        'caregivers': caregivers.map((c) => c.toJson()).toList(),
        'schedule': schedule.toJson(),
        'inviteCode': inviteCode,
        'createdAt': createdAt == null ? null : _ts(createdAt!),
      };

  factory Household.fromJson(Map<String, dynamic> j) => Household(
        id: j['id'] as String,
        baby: BabyProfile.fromJson(Map<String, dynamic>.from(j['baby'] as Map)),
        caregivers: (j['caregivers'] as List? ?? [])
            .map((e) => Caregiver.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        schedule: FeedingSchedule.fromJson(Map<String, dynamic>.from(j['schedule'] as Map)),
        inviteCode: j['inviteCode'] as String?,
        createdAt: j['createdAt'] == null ? null : _dt(j['createdAt']),
      );

  Household copyWith({
    BabyProfile? baby,
    List<Caregiver>? caregivers,
    FeedingSchedule? schedule,
    String? inviteCode,
  }) =>
      Household(
        id: id,
        baby: baby ?? this.baby,
        caregivers: caregivers ?? this.caregivers,
        schedule: schedule ?? this.schedule,
        inviteCode: inviteCode ?? this.inviteCode,
        createdAt: createdAt,
      );
}
