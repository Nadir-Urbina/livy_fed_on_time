import 'dart:math';

import '../models/badge_catalog.dart';
import '../models/models.dart';
import 'repository.dart';

/// Seeds the clearly-labeled demo household: a sample baby, a week of
/// realistic feed history from two caregivers, a couple of earned badges and
/// live streaks — so every feature is demonstrable with no Firebase project.
HouseholdBundle buildDemoBundle() {
  final rng = Random(7);
  final now = DateTime.now();

  const you = Caregiver(id: 'demo-you', name: 'You', role: CaregiverRole.accountHolder);
  const jordan = Caregiver(id: 'demo-jordan', name: 'Jordan', role: CaregiverRole.caregiver);

  final baby = BabyProfile(
    name: 'Olivia',
    birthDate: now.subtract(const Duration(days: 78)),
  );

  // A week of feeds, roughly every 3h drifting toward 3.5h — the interval
  // stretch that Livy's recommendation engine will notice.
  final feeds = <Feed>[];
  var id = 0;
  for (var day = 7; day >= 0; day--) {
    final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: day));
    final drift = (7 - day) * 4; // minutes added per day as baby grows
    var t = dayStart.add(const Duration(hours: 6, minutes: 30));
    var caregiverToggle = day.isEven;
    while (t.isBefore(dayStart.add(const Duration(hours: 23)))) {
      if (day == 0 && t.isAfter(now.subtract(const Duration(hours: 2)))) break;
      final who = caregiverToggle ? you : jordan;
      caregiverToggle = !caregiverToggle;
      final amount = 110.0 + (7 - day) * 3 + rng.nextInt(20) - 10; // trending up, in mL
      final symptoms = <SymptomNote>[];
      if (rng.nextInt(6) == 0) {
        symptoms.add(const SymptomNote(kind: SymptomKind.gas, note: 'A little gassy after this one'));
      }
      if (rng.nextInt(9) == 0) {
        symptoms.add(const SymptomNote(kind: SymptomKind.spitUp, note: 'Small spit-up, seemed comfy after'));
      }
      feeds.add(Feed(
        id: 'demo-feed-${id++}',
        time: t.add(Duration(minutes: rng.nextInt(24) - 12)),
        amountMl: amount.clamp(60, 210).toDouble(),
        loggedById: who.id,
        loggedByName: who.name,
        formulaBrand: day > 5 ? 'Kendamil Classic' : 'Similac 360 Total Care',
        symptoms: symptoms,
      ));
      t = t.add(Duration(minutes: 180 + drift + rng.nextInt(20)));
    }
  }
  feeds.sort((a, b) => b.time.compareTo(a.time));

  final household = Household(
    id: 'demo-household',
    baby: baby,
    caregivers: const [you, jordan],
    schedule: const FeedingSchedule(intervalMinutes: 195),
    inviteCode: 'LIVY-OLIVIA',
    createdAt: now.subtract(const Duration(days: 8)),
  );

  final badges = [
    BadgeUnlock(
      badgeId: 'tagteam_first',
      unlockedAt: now.subtract(const Duration(days: 6)),
      unlockedBy: 'You & Jordan',
    ),
    BadgeUnlock(
      badgeId: 'logging_3',
      unlockedAt: now.subtract(const Duration(days: 4)),
      unlockedBy: 'You',
    ),
    BadgeUnlock(
      badgeId: 'ontime_3',
      unlockedAt: now.subtract(const Duration(days: 3)),
      unlockedBy: 'Jordan',
    ),
  ];

  final switches = [
    FormulaSwitchEntry(
      id: 'demo-switch-1',
      date: now.subtract(const Duration(days: 40)),
      brand: 'Kendamil Classic',
      reason: 'Starting formula recommended by our hospital',
      response: 'Took to it well, occasional gas in week two',
    ),
    FormulaSwitchEntry(
      id: 'demo-switch-2',
      date: now.subtract(const Duration(days: 6)),
      brand: 'Similac 360 Total Care',
      reason: 'Kendamil was out of stock at two stores',
      response: 'Smooth switch — slightly less spit-up so far',
    ),
  ];

  final recommendations = [
    LivyRecommendation(
      id: 'demo-rec-1',
      kind: RecommendationKind.intervalDrift,
      text:
          'Feeds have naturally stretched from about every 3h to every 3h 15m over the past week. Growing babies often go a little longer between bottles — if this keeps up, you may want to update the schedule. ${LivyRecommendation.disclaimer}',
      createdAt: now.subtract(const Duration(hours: 20)),
    ),
  ];

  return HouseholdBundle(
    household: household,
    feeds: feeds,
    recommendations: recommendations,
    formulaSwitches: switches,
    streaks: StreakState(
      onTimeStreakDays: 4,
      loggingStreakDays: 6,
      tagTeamStreakDays: 3,
      bestOnTimeStreak: 4,
      bestLoggingStreak: 6,
      bestTagTeamStreak: 3,
      lastUpdatedDay: DateTime(now.year, now.month, now.day),
    ),
    badges: badges,
    mascot: const MascotState(),
  );
}

/// Demo recall notices — served by the mock [RecallDataSource]; a real FDA
/// feed replaces this before ship (see README).
List<RecallNotice> buildDemoRecalls(DateTime now) => [
      RecallNotice(
        id: 'demo-recall-1',
        brand: 'Similac 360 Total Care',
        title: 'Voluntary recall — specific lot codes (sample data)',
        summary:
            'SAMPLE NOTICE for demonstration: the manufacturer voluntarily recalled a limited set of lots after routine testing. Check your can’s lot code against the list below. This is placeholder data — connect the real FDA feed before shipping.',
        publishedAt: now.subtract(const Duration(days: 12)),
        lotCodes: ['27032K80', '27032K800', '37352K80'],
        link: 'https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts',
      ),
      RecallNotice(
        id: 'demo-recall-2',
        brand: 'Generic Store Brand',
        title: 'Advisory — packaging defect (sample data)',
        summary:
            'SAMPLE NOTICE for demonstration: a packaging seal defect was reported for a small number of tubs. No illness reported. This is placeholder data — connect the real FDA feed before shipping.',
        publishedAt: now.subtract(const Duration(days: 30)),
        lotCodes: ['B2210-EX'],
        link: 'https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts',
      ),
    ];
