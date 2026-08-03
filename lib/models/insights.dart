import 'package:flutter/foundation.dart';

import 'models.dart';

/// One day of feeding, condensed. Rollups are what long-window analytics read
/// instead of thousands of individual feed docs: ~90 tiny documents cover a
/// quarter of history, which keeps both Firestore reads and render cost flat
/// as a household's log grows.
///
/// `hourCounts` and `byCaregiver` are maps (not lists) so Firestore can
/// increment a single bucket in place — e.g. `hourCounts.14: increment(1)`.
@immutable
class DailyRollup {
  const DailyRollup({
    required this.day,
    required this.count,
    required this.totalMl,
    this.hourCounts = const {},
    this.byCaregiver = const {},
  });

  /// Local midnight of the day being summarized.
  final DateTime day;
  final int count;
  final double totalMl;

  /// Hour of day (0–23) → feeds started in that hour.
  final Map<int, int> hourCounts;

  /// Caregiver id → feeds they logged that day.
  final Map<String, int> byCaregiver;

  double get avgMl => count == 0 ? 0 : totalMl / count;

  /// Feeds between 10pm and 6am — the number every exhausted parent watches.
  int get nightFeeds {
    var n = 0;
    for (final h in const [22, 23, 0, 1, 2, 3, 4, 5]) {
      n += hourCounts[h] ?? 0;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'day': day.millisecondsSinceEpoch,
        'count': count,
        'totalMl': totalMl,
        'hourCounts': hourCounts.map((k, v) => MapEntry('$k', v)),
        'byCaregiver': byCaregiver,
      };

  factory DailyRollup.fromJson(Map<String, dynamic> j) => DailyRollup(
        day: DateTime.fromMillisecondsSinceEpoch(j['day'] as int? ?? 0),
        count: (j['count'] as num?)?.toInt() ?? 0,
        totalMl: (j['totalMl'] as num?)?.toDouble() ?? 0,
        hourCounts: ((j['hourCounts'] as Map?) ?? {}).map(
            (k, v) => MapEntry(int.tryParse('$k') ?? 0, (v as num).toInt())),
        byCaregiver: ((j['byCaregiver'] as Map?) ?? {})
            .map((k, v) => MapEntry('$k', (v as num).toInt())),
      );

  /// Firestore document id for a given day — stable and sortable.
  static String docId(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// A week's worth of change, in the shape Livy talks about it.
@immutable
class WeeklyDigest {
  const WeeklyDigest({
    required this.weekStart,
    required this.feeds,
    required this.totalMl,
    required this.avgMl,
    required this.nightFeeds,
    required this.avgIntervalMinutes,
    required this.feedsDelta,
    required this.avgMlDelta,
    required this.nightFeedsDelta,
    required this.intervalDeltaMinutes,
    required this.caregiverSplit,
    required this.hasPreviousWeek,
  });

  final DateTime weekStart;
  final int feeds;
  final double totalMl;
  final double avgMl;
  final int nightFeeds;
  final double avgIntervalMinutes;

  /// Deltas vs. the previous 7 days (0 when there's no prior week yet).
  final int feedsDelta;
  final double avgMlDelta;
  final int nightFeedsDelta;
  final double intervalDeltaMinutes;

  /// Caregiver id → feeds logged this week.
  final Map<String, int> caregiverSplit;
  final bool hasPreviousWeek;
}

abstract final class InsightsEngine {
  static DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Condenses raw feeds into per-day rollups. Used for demo mode, for history
  /// logged before rollups existed, and as the authoritative value for any day
  /// still inside the live feed window.
  static List<DailyRollup> fromFeeds(List<Feed> feeds) {
    final byDay = <DateTime, List<Feed>>{};
    for (final f in feeds) {
      byDay.putIfAbsent(dayOf(f.time), () => []).add(f);
    }
    final out = <DailyRollup>[];
    byDay.forEach((day, list) {
      final hours = <int, int>{};
      final caregivers = <String, int>{};
      var total = 0.0;
      for (final f in list) {
        hours[f.time.hour] = (hours[f.time.hour] ?? 0) + 1;
        caregivers[f.loggedById] = (caregivers[f.loggedById] ?? 0) + 1;
        total += f.amountMl;
      }
      out.add(DailyRollup(
        day: day,
        count: list.length,
        totalMl: total,
        hourCounts: hours,
        byCaregiver: caregivers,
      ));
    });
    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  /// Stored rollups cover deep history; freshly-computed ones cover the live
  /// feed window. Computed wins on overlap — it can't drift.
  static List<DailyRollup> merge(List<DailyRollup> stored, List<Feed> feeds) {
    final byDay = <DateTime, DailyRollup>{};
    for (final r in stored) {
      byDay[dayOf(r.day)] = r;
    }
    for (final r in fromFeeds(feeds)) {
      byDay[r.day] = r;
    }
    final out = byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  /// Last [days] days, oldest first, with empty days filled in so the heatmap
  /// shows honest gaps rather than silently compressing them.
  static List<DailyRollup> window(List<DailyRollup> rollups, {int days = 21}) {
    final byDay = {for (final r in rollups) dayOf(r.day): r};
    final today = dayOf(DateTime.now());
    return List.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return byDay[d] ?? DailyRollup(day: d, count: 0, totalMl: 0);
    });
  }

  /// Average minutes between consecutive feeds within each day (overnight
  /// stretches over 8h are excluded — they'd swamp the daytime rhythm).
  static double avgIntervalMinutes(List<Feed> feeds, DateTime from, DateTime to) {
    final inRange = feeds
        .where((f) => !f.time.isBefore(from) && f.time.isBefore(to))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    final gaps = <int>[];
    for (var i = 1; i < inRange.length; i++) {
      final g = inRange[i].time.difference(inRange[i - 1].time).inMinutes;
      if (g > 30 && g < 8 * 60) gaps.add(g);
    }
    if (gaps.isEmpty) return 0;
    return gaps.reduce((a, b) => a + b) / gaps.length;
  }

  /// Builds this week's digest (the trailing 7 days) against the 7 before it.
  static WeeklyDigest? digest(List<DailyRollup> rollups, List<Feed> feeds) {
    final today = dayOf(DateTime.now());
    final thisStart = today.subtract(const Duration(days: 6));
    final prevStart = today.subtract(const Duration(days: 13));

    final byDay = {for (final r in rollups) dayOf(r.day): r};
    List<DailyRollup> span(DateTime start, int days) => List.generate(
        days,
        (i) => byDay[start.add(Duration(days: i))] ??
            DailyRollup(day: start.add(Duration(days: i)), count: 0, totalMl: 0));

    final thisWeek = span(thisStart, 7);
    final prevWeek = span(prevStart, 7);

    final feedsNow = thisWeek.fold<int>(0, (s, r) => s + r.count);
    if (feedsNow == 0) return null;

    final feedsPrev = prevWeek.fold<int>(0, (s, r) => s + r.count);
    final totalNow = thisWeek.fold<double>(0, (s, r) => s + r.totalMl);
    final totalPrev = prevWeek.fold<double>(0, (s, r) => s + r.totalMl);
    final avgNow = feedsNow == 0 ? 0.0 : totalNow / feedsNow;
    final avgPrev = feedsPrev == 0 ? 0.0 : totalPrev / feedsPrev;
    final nightNow = thisWeek.fold<int>(0, (s, r) => s + r.nightFeeds);
    final nightPrev = prevWeek.fold<int>(0, (s, r) => s + r.nightFeeds);

    final intervalNow = avgIntervalMinutes(
        feeds, thisStart, today.add(const Duration(days: 1)));
    final intervalPrev = avgIntervalMinutes(feeds, prevStart, thisStart);

    final split = <String, int>{};
    for (final r in thisWeek) {
      r.byCaregiver.forEach((k, v) => split[k] = (split[k] ?? 0) + v);
    }

    return WeeklyDigest(
      weekStart: thisStart,
      feeds: feedsNow,
      totalMl: totalNow,
      avgMl: avgNow,
      nightFeeds: nightNow,
      avgIntervalMinutes: intervalNow,
      feedsDelta: feedsNow - feedsPrev,
      avgMlDelta: avgPrev == 0 ? 0 : avgNow - avgPrev,
      nightFeedsDelta: feedsPrev == 0 ? 0 : nightNow - nightPrev,
      intervalDeltaMinutes:
          intervalPrev == 0 ? 0 : intervalNow - intervalPrev,
      caregiverSplit: split,
      hasPreviousWeek: feedsPrev > 0,
    );
  }
}
