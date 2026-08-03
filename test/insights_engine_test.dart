import 'package:flutter_test/flutter_test.dart';
import 'package:livy_fed_on_time/models/insights.dart';
import 'package:livy_fed_on_time/models/models.dart';

Feed feedAt(DateTime t, {double ml = 120, String by = 'a'}) => Feed(
      id: '${t.millisecondsSinceEpoch}-$by',
      time: t,
      amountMl: ml,
      loggedById: by,
      loggedByName: by,
    );

void main() {
  final today = InsightsEngine.dayOf(DateTime.now());

  group('rollups from feeds', () {
    test('buckets by day, hour and caregiver', () {
      final d = today.subtract(const Duration(days: 1));
      final feeds = [
        feedAt(d.add(const Duration(hours: 2)), ml: 100, by: 'a'), // night
        feedAt(d.add(const Duration(hours: 2, minutes: 40)), ml: 110, by: 'b'),
        feedAt(d.add(const Duration(hours: 14)), ml: 150, by: 'a'), // day
      ];

      final rollups = InsightsEngine.fromFeeds(feeds);
      expect(rollups, hasLength(1));

      final r = rollups.single;
      expect(r.count, 3);
      expect(r.totalMl, 360);
      expect(r.avgMl, closeTo(120, 0.01));
      expect(r.hourCounts[2], 2);
      expect(r.hourCounts[14], 1);
      expect(r.byCaregiver['a'], 2);
      expect(r.byCaregiver['b'], 1);
      // 2am counts as night, 2pm does not.
      expect(r.nightFeeds, 2);
    });

    test('nightFeeds spans the 10pm–6am wrap', () {
      final feeds = [
        feedAt(today.add(const Duration(hours: 23))),
        feedAt(today.add(const Duration(hours: 5))),
        feedAt(today.add(const Duration(hours: 6))), // 6am is morning
        feedAt(today.add(const Duration(hours: 21))), // 9pm is evening
      ];
      expect(InsightsEngine.fromFeeds(feeds).single.nightFeeds, 2);
    });
  });

  group('merge', () {
    test('computed rollups win over stored ones for the same day', () {
      final stored = [
        DailyRollup(day: today, count: 99, totalMl: 9999, hourCounts: {3: 99}),
      ];
      final feeds = [feedAt(today.add(const Duration(hours: 8)))];

      final merged = InsightsEngine.merge(stored, feeds);
      expect(merged, hasLength(1));
      expect(merged.single.count, 1, reason: 'live feeds are authoritative');
    });

    test('stored rollups survive for days outside the feed window', () {
      final old = today.subtract(const Duration(days: 120));
      final stored = [DailyRollup(day: old, count: 7, totalMl: 700)];
      final feeds = [feedAt(today.add(const Duration(hours: 8)))];

      final merged = InsightsEngine.merge(stored, feeds);
      expect(merged, hasLength(2));
      expect(merged.first.day, old);
      expect(merged.first.count, 7);
    });
  });

  group('window', () {
    test('fills gaps so empty days stay visible', () {
      final feeds = [feedAt(today.add(const Duration(hours: 9)))];
      final w = InsightsEngine.window(InsightsEngine.fromFeeds(feeds), days: 7);

      expect(w, hasLength(7));
      expect(w.last.day, today);
      expect(w.last.count, 1);
      expect(w.take(6).every((r) => r.count == 0), isTrue);
    });
  });

  group('weekly digest', () {
    /// Eight feeds a day at a given interval, for a span of days ending N days ago.
    List<Feed> week(int startDaysAgo, {required int nightFeeds, double ml = 120}) {
      final out = <Feed>[];
      for (var d = 0; d < 7; d++) {
        final day = today.subtract(Duration(days: startDaysAgo - d));
        for (var i = 0; i < 4; i++) {
          out.add(feedAt(day.add(Duration(hours: 8 + i * 3)), ml: ml));
        }
        for (var n = 0; n < nightFeeds; n++) {
          out.add(feedAt(day.add(Duration(hours: 1 + n)), ml: ml));
        }
      }
      return out;
    }

    test('reports week-over-week deltas', () {
      // Previous week: 2 night feeds/day. This week: 1. Volume up 20mL.
      final feeds = [
        ...week(13, nightFeeds: 2, ml: 110),
        ...week(6, nightFeeds: 1, ml: 130),
      ];
      final digest =
          InsightsEngine.digest(InsightsEngine.fromFeeds(feeds), feeds)!;

      expect(digest.hasPreviousWeek, isTrue);
      expect(digest.feeds, 7 * 5);
      expect(digest.nightFeeds, 7);
      expect(digest.nightFeedsDelta, -7, reason: 'nights got quieter');
      expect(digest.avgMlDelta, closeTo(20, 0.01));
      expect(digest.caregiverSplit['a'], 7 * 5);
    });

    test('flags the first week when there is no prior data', () {
      final feeds = week(6, nightFeeds: 1);
      final digest =
          InsightsEngine.digest(InsightsEngine.fromFeeds(feeds), feeds)!;

      expect(digest.hasPreviousWeek, isFalse);
      expect(digest.feedsDelta, isNot(0),
          reason: 'delta exists but UI suppresses it via hasPreviousWeek');
      expect(digest.avgMlDelta, 0);
      expect(digest.nightFeedsDelta, 0);
    });

    test('returns null when the week is empty', () {
      expect(InsightsEngine.digest(const [], const []), isNull);
    });

    test('average interval ignores overnight stretches', () {
      final d = today.subtract(const Duration(days: 1));
      final feeds = [
        feedAt(d.add(const Duration(hours: 8))),
        feedAt(d.add(const Duration(hours: 11))), // 180m — counted
        feedAt(d.add(const Duration(hours: 22))), // 660m — excluded (>8h)
      ];
      final avg = InsightsEngine.avgIntervalMinutes(
          feeds, d, d.add(const Duration(days: 1)));
      expect(avg, closeTo(180, 0.01));
    });
  });

  group('rollup serialization', () {
    test('survives a JSON round trip with string-keyed maps', () {
      final r = DailyRollup(
        day: today,
        count: 3,
        totalMl: 360,
        hourCounts: const {2: 2, 14: 1},
        byCaregiver: const {'a': 2, 'b': 1},
      );
      final back = DailyRollup.fromJson(r.toJson());

      expect(back.day, r.day);
      expect(back.count, 3);
      expect(back.totalMl, 360);
      expect(back.hourCounts, {2: 2, 14: 1});
      expect(back.byCaregiver, {'a': 2, 'b': 1});
    });

    test('docId is stable and sortable', () {
      expect(DailyRollup.docId(DateTime(2026, 7, 5)), '2026-07-05');
      expect(DailyRollup.docId(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
