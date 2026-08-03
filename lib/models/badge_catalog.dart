import 'package:flutter/foundation.dart';

/// Badge tracks mirror what Livy celebrates: feeding on time, logging
/// consistently, tag-team handoffs, and lifetime milestones.
enum BadgeTrack { onTime, logging, tagTeam, milestone }

@immutable
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.track,
    required this.title,
    required this.flavor,
    required this.threshold,
  });

  final String id;
  final BadgeTrack track;
  final String title;

  /// Livy's voice on the unlock card.
  final String flavor;

  /// Days of streak (streak tracks) or total feeds (milestone track).
  final int threshold;

  String get asset => 'assets/badges/$id.png';
}

@immutable
class BadgeUnlock {
  const BadgeUnlock({required this.badgeId, required this.unlockedAt, required this.unlockedBy});

  final String badgeId;
  final DateTime unlockedAt;
  final String unlockedBy;

  Map<String, dynamic> toJson() => {
        'badgeId': badgeId,
        'unlockedAt': unlockedAt.millisecondsSinceEpoch,
        'unlockedBy': unlockedBy,
      };

  factory BadgeUnlock.fromJson(Map<String, dynamic> j) => BadgeUnlock(
        badgeId: j['badgeId'] as String,
        unlockedAt: DateTime.fromMillisecondsSinceEpoch(j['unlockedAt'] as int? ?? 0),
        unlockedBy: j['unlockedBy'] as String? ?? '',
      );
}

abstract final class BadgeCatalog {
  static const List<BadgeDef> all = [
    // On-time streaks.
    BadgeDef(
      id: 'ontime_3',
      track: BadgeTrack.onTime,
      title: 'Right On Time',
      flavor: 'Three days of feeds on schedule. The clock is learning your name, dear.',
      threshold: 3,
    ),
    BadgeDef(
      id: 'ontime_7',
      track: BadgeTrack.onTime,
      title: 'Clockwork Week',
      flavor: 'Seven days on schedule. I have known grandfather clocks less reliable.',
      threshold: 7,
    ),
    BadgeDef(
      id: 'ontime_30',
      track: BadgeTrack.onTime,
      title: 'Golden Hour',
      flavor: 'A whole month on time. You could set the sunrise by this family.',
      threshold: 30,
    ),
    // Logging consistency.
    BadgeDef(
      id: 'logging_3',
      track: BadgeTrack.logging,
      title: 'Every Drop Counted',
      flavor: 'Three days with every feed logged. A tidy record warms my heart.',
      threshold: 3,
    ),
    BadgeDef(
      id: 'logging_7',
      track: BadgeTrack.logging,
      title: 'The Ledger Keeper',
      flavor: 'A full week, nothing missed. My knitting has dropped more stitches than you.',
      threshold: 7,
    ),
    BadgeDef(
      id: 'logging_30',
      track: BadgeTrack.logging,
      title: 'Archivist of Ounces',
      flavor: 'Thirty days of perfect records. Historians will thank you. I already do.',
      threshold: 30,
    ),
    // Tag-team handoffs.
    BadgeDef(
      id: 'tagteam_first',
      track: BadgeTrack.tagTeam,
      title: 'The Handoff',
      flavor: 'Two caregivers, back-to-back feeds. That, my dears, is teamwork.',
      threshold: 1,
    ),
    BadgeDef(
      id: 'tagteam_7',
      track: BadgeTrack.tagTeam,
      title: 'Relay Champions',
      flavor: 'A week of sharing the load. The baton is a bottle, and you never drop it.',
      threshold: 7,
    ),
    // Milestone feed counts.
    BadgeDef(
      id: 'feeds_50',
      track: BadgeTrack.milestone,
      title: 'Fifty Bottles Strong',
      flavor: 'Fifty feeds logged together. Look how far this little one has come.',
      threshold: 50,
    ),
    BadgeDef(
      id: 'feeds_100',
      track: BadgeTrack.milestone,
      title: 'The Hundred Club',
      flavor: 'One hundred feeds. If bottles were bricks, you\'d have built a cottage.',
      threshold: 100,
    ),
    BadgeDef(
      id: 'feeds_250',
      track: BadgeTrack.milestone,
      title: 'Constellation of Care',
      flavor: 'Two hundred and fifty feeds — a night sky of small kindnesses.',
      threshold: 250,
    ),
  ];

  static BadgeDef? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }
}
