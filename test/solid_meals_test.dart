import 'package:flutter_test/flutter_test.dart';
import 'package:livy_fed_on_time/data/app_state.dart';
import 'package:livy_fed_on_time/data/local_repository.dart';
import 'package:livy_fed_on_time/data/repository.dart';
import 'package:livy_fed_on_time/models/models.dart';
import 'package:livy_fed_on_time/services/recommendation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Solids are stored apart from feeds precisely so they can never disturb the
/// bottle countdown, the streaks or any mL figure. These lock that in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> seededApp() async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState(repository: LocalRepository(isDemo: true, seedDemoData: true));
    await app.init();
    return app;
  }

  group('a solid meal leaves the bottle countdown alone', () {
    test('logging a meal moves neither lastFeed nor the dial', () async {
      final app = await seededApp();
      final feedBefore = app.lastFeed;
      final progressBefore = app.dialProgress;
      final dueBefore = app.nextFeedDue;
      final feedCountBefore = app.bundle!.feeds.length;

      await app.logMeal(foods: ['Sweet potato'], reaction: MealReaction.loved);

      expect(app.lastFeed?.id, feedBefore?.id, reason: 'last bottle must not change');
      expect(app.nextFeedDue, dueBefore, reason: 'the countdown target must hold');
      expect(app.dialProgress, closeTo(progressBefore, 0.001));
      expect(app.bundle!.feeds.length, feedCountBefore,
          reason: 'a meal is not a feed');
    });

    test('the meal is recorded and surfaces as the latest', () async {
      final app = await seededApp();
      await app.logMeal(foods: ['Pear', 'Oatmeal']);

      expect(app.lastMeal, isNotNull);
      expect(app.lastMeal!.foodLabel, 'Pear · Oatmeal');
      expect(app.isEatingSolids, isTrue);
    });

    test('meals stay out of the daily rollups Insights charts', () async {
      final app = await seededApp();
      final mlBefore = app.bundle!.rollups.fold<double>(0, (s, r) => s + r.totalMl);
      final countBefore = app.bundle!.rollups.fold<int>(0, (s, r) => s + r.count);

      await app.logMeal(foods: ['Banana']);

      final mlAfter = app.bundle!.rollups.fold<double>(0, (s, r) => s + r.totalMl);
      final countAfter = app.bundle!.rollups.fold<int>(0, (s, r) => s + r.count);
      expect(mlAfter, mlBefore);
      expect(countAfter, countBefore);
    });

    test('a household with no meals shows nothing to hide behind', () async {
      final app = await seededApp();
      expect(app.lastMeal, isNull);
      expect(app.isEatingSolids, isFalse);
    });
  });

  group('a falling bottle volume reads differently once solids start', () {
    /// 30 feeds: the newer half deliberately ~30% smaller, the shape of a
    /// baby whose bottles are shrinking.
    HouseholdBundle bundleWithTaper({
      required List<SolidMeal> meals,
      int babyAgeMonths = 8,
    }) {
      final now = DateTime.now();
      final feeds = <Feed>[];
      for (var i = 0; i < 30; i++) {
        feeds.add(Feed(
          id: 'f$i',
          time: now.subtract(Duration(hours: (30 - i) * 4)),
          amountMl: i < 15 ? 200 : 140,
          loggedById: 'me',
          loggedByName: 'Me',
        ));
      }
      return HouseholdBundle(
        household: Household(
          id: 'h',
          baby: BabyProfile(
              name: 'Olivia',
              birthDate: now.subtract(Duration(days: (babyAgeMonths * 30.44).round()))),
          caregivers: const [
            Caregiver(id: 'me', name: 'Me', role: CaregiverRole.accountHolder)
          ],
          schedule: const FeedingSchedule(intervalMinutes: 240),
        ),
        feeds: feeds,
        meals: meals,
      );
    }

    test('old enough for solids but none logged, it asks instead of worrying', () {
      final rec = RecommendationEngine.evaluate(
          bundleWithTaper(meals: const [], babyAgeMonths: 8));
      expect(rec, isNotNull);
      expect(rec!.text, contains('Has Olivia started solid meals?'));
      expect(rec.text, contains('logging them'));
    });

    test('too young for solids, the original gentle flag still stands', () {
      // Asking a parent of a 3-month-old about solids would be the wrong
      // prompt entirely.
      final rec = RecommendationEngine.evaluate(
          bundleWithTaper(meals: const [], babyAgeMonths: 3));
      expect(rec, isNotNull);
      expect(rec!.text, contains('dipped'));
      expect(rec.text, contains('gentle eye'));
      expect(rec.text, isNot(contains('solid meals?')));
    });

    test('with solids the same numbers are framed as the expected trade', () {
      final rec = RecommendationEngine.evaluate(bundleWithTaper(meals: [
        SolidMeal(
          id: 'm1',
          time: DateTime.now().subtract(const Duration(days: 2)),
          loggedById: 'me',
          loggedByName: 'Me',
          foods: const ['Sweet potato'],
        ),
      ]));
      expect(rec, isNotNull);
      expect(rec!.text, contains('meals fill in'));
      expect(rec.text, isNot(contains('gentle eye')),
          reason: 'weaning must not be framed as something to watch');
    });
  });
}
