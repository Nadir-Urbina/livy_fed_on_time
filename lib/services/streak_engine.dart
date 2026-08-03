import '../data/repository.dart';
import '../models/badge_catalog.dart';
import '../models/models.dart';

/// Pure functions that recompute streaks and badge unlocks from the shared
/// history. Runs after every logged feed and once per app foreground.
///
/// Day rules (a "day" is a local calendar day, evaluated for *completed* days
/// and today-so-far):
///  - logging day: at least 4 feeds logged that day (a genuinely tracked day).
///  - on-time day: a logging day where >= 80% of gaps between consecutive
///    feeds were within ±25 minutes of the scheduled interval.
///  - tag-team day: a logging day where two different caregivers logged
///    consecutive feeds at least once.
class StreakComputation {
  const StreakComputation({
    required this.streaks,
    required this.newBadges,
  });

  final StreakState streaks;
  final List<BadgeDef> newBadges;
}

class StreakEngine {
  static const int minFeedsForTrackedDay = 4;
  static const Duration onTimeTolerance = Duration(minutes: 25);
  static const double onTimeRatio = 0.8;

  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static StreakComputation recompute(HouseholdBundle bundle) {
    final feeds = [...bundle.feeds]..sort((a, b) => a.time.compareTo(b.time));
    final interval = bundle.household.schedule.interval;
    final today = dayOf(DateTime.now());

    final byDay = <DateTime, List<Feed>>{};
    for (final f in feeds) {
      byDay.putIfAbsent(dayOf(f.time), () => []).add(f);
    }

    bool loggingDay(DateTime day) => (byDay[day]?.length ?? 0) >= minFeedsForTrackedDay;

    bool onTimeDay(DateTime day) {
      final list = byDay[day];
      if (list == null || list.length < 2) return false;
      var ok = 0, total = 0;
      for (var i = 1; i < list.length; i++) {
        final gap = list[i].time.difference(list[i - 1].time);
        total++;
        if ((gap - interval).abs() <= onTimeTolerance) ok++;
      }
      return total > 0 && ok / total >= onTimeRatio;
    }

    bool tagTeamDay(DateTime day) {
      final list = byDay[day];
      if (list == null || list.length < 2) return false;
      for (var i = 1; i < list.length; i++) {
        if (list[i].loggedById != list[i - 1].loggedById) return true;
      }
      return false;
    }

    // Walk back from yesterday counting consecutive qualifying days; today
    // extends the streak as soon as it qualifies but never breaks it. The
    // single streak-freeze forgives one missed day.
    int countStreak(bool Function(DateTime) qualifies, {required bool freezeAllowed}) {
      var streak = qualifies(today) ? 1 : 0;
      var freezeLeft = freezeAllowed && bundle.streaks.freezeAvailable ? 1 : 0;
      var day = today.subtract(const Duration(days: 1));
      for (var i = 0; i < 365; i++) {
        if (qualifies(day)) {
          streak++;
        } else if (freezeLeft > 0 && byDay.containsKey(day)) {
          // Partial day: freeze covers it without extending the count.
          freezeLeft--;
        } else {
          break;
        }
        day = day.subtract(const Duration(days: 1));
      }
      return streak;
    }

    final logging = countStreak(loggingDay, freezeAllowed: true);
    final onTime = countStreak(onTimeDay, freezeAllowed: true);
    final tagTeam = countStreak(tagTeamDay, freezeAllowed: false);

    final prev = bundle.streaks;
    final next = prev.copyWith(
      loggingStreakDays: logging,
      onTimeStreakDays: onTime,
      tagTeamStreakDays: tagTeam,
      bestLoggingStreak: logging > prev.bestLoggingStreak ? logging : prev.bestLoggingStreak,
      bestOnTimeStreak: onTime > prev.bestOnTimeStreak ? onTime : prev.bestOnTimeStreak,
      bestTagTeamStreak: tagTeam > prev.bestTagTeamStreak ? tagTeam : prev.bestTagTeamStreak,
      lastUpdatedDay: today,
    );

    final newBadges = <BadgeDef>[];
    for (final def in BadgeCatalog.all) {
      if (bundle.hasBadge(def.id)) continue;
      final earned = switch (def.track) {
        BadgeTrack.onTime => onTime >= def.threshold,
        BadgeTrack.logging => logging >= def.threshold,
        BadgeTrack.tagTeam =>
          def.id == 'tagteam_first' ? feeds.any((_) => _hasAnyHandoff(byDay)) : tagTeam >= def.threshold,
        BadgeTrack.milestone => feeds.length >= def.threshold,
      };
      if (earned) newBadges.add(def);
    }

    return StreakComputation(streaks: next, newBadges: newBadges);
  }

  static bool _hasAnyHandoff(Map<DateTime, List<Feed>> byDay) {
    for (final list in byDay.values) {
      for (var i = 1; i < list.length; i++) {
        if (list[i].loggedById != list[i - 1].loggedById) return true;
      }
    }
    return false;
  }

  /// Whether the feed just logged landed within the on-time window of the
  /// schedule — drives Livy's proud pose + the on-time celebration.
  static bool feedWasOnTime(Feed feed, Feed? previous, FeedingSchedule schedule) {
    if (previous == null) return true;
    final gap = feed.time.difference(previous.time);
    return (gap - schedule.interval).abs() <= onTimeTolerance;
  }
}
