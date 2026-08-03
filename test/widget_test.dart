import 'package:flutter_test/flutter_test.dart';

import 'package:livy_fed_on_time/data/demo_seed.dart';
import 'package:livy_fed_on_time/data/repository.dart';
import 'package:livy_fed_on_time/models/models.dart';
import 'package:livy_fed_on_time/services/recommendation_engine.dart';
import 'package:livy_fed_on_time/services/streak_engine.dart';

void main() {
  group('demo seed', () {
    test('builds a full household with a week of history', () {
      final bundle = buildDemoBundle();
      expect(bundle.household.caregivers.length, 2);
      expect(bundle.feeds.length, greaterThan(30));
      expect(bundle.badges.length, greaterThanOrEqualTo(3));
      expect(bundle.mascot.mascotId, 'granny');
    });

    test('round-trips through JSON', () {
      final bundle = buildDemoBundle();
      final restored = HouseholdBundle.fromJson(bundle.toJson());
      expect(restored.feeds.length, bundle.feeds.length);
      expect(restored.household.schedule.intervalMinutes,
          bundle.household.schedule.intervalMinutes);
      expect(restored.streaks.loggingStreakDays, bundle.streaks.loggingStreakDays);
    });
  });

  group('streak engine', () {
    test('recomputes streaks from the demo history', () {
      final bundle = buildDemoBundle();
      final result = StreakEngine.recompute(bundle);
      expect(result.streaks.loggingStreakDays, greaterThan(0));
      expect(
        result.newBadges.any((b) => b.id == 'feeds_50') || bundle.hasBadge('feeds_50'),
        bundle.feeds.length >= 50,
      );
    });

    test('on-time check respects the ±25 minute window', () {
      const schedule = FeedingSchedule(intervalMinutes: 180);
      final prev = Feed(
        id: 'a',
        time: DateTime(2026, 1, 1, 9),
        amountMl: 100,
        loggedById: 'x',
        loggedByName: 'X',
      );
      final onTime = Feed(
        id: 'b',
        time: DateTime(2026, 1, 1, 12, 10),
        amountMl: 100,
        loggedById: 'x',
        loggedByName: 'X',
      );
      final late = Feed(
        id: 'c',
        time: DateTime(2026, 1, 1, 13, 30),
        amountMl: 100,
        loggedById: 'x',
        loggedByName: 'X',
      );
      expect(StreakEngine.feedWasOnTime(onTime, prev, schedule), isTrue);
      expect(StreakEngine.feedWasOnTime(late, prev, schedule), isFalse);
    });
  });

  group('recommendation engine', () {
    test('every generated recommendation carries the pediatrician disclaimer', () {
      final bundle = buildDemoBundle();
      final rec = RecommendationEngine.evaluate(
        bundle.copyWith(recommendations: const []),
      );
      if (rec != null) {
        expect(rec.text, contains(LivyRecommendation.disclaimer));
      }
    });
  });
}
