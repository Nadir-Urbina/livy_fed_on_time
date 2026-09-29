import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livy_fed_on_time/services/review_prompt_service.dart';

/// The rules that keep the rating ask from becoming nagging. They're invisible
/// when they work, so they're worth pinning down.
void main() {
  late ReviewPromptService service;

  Future<void> reset([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    service = ReviewPromptService.instance;
    // The singleton caches its prefs handle, so clear it between cases.
    await service.init();
  }

  setUp(() => reset());

  test('stays quiet until the household has really used the app', () async {
    expect(service.shouldAsk(feedCount: 0), isFalse);
    expect(service.shouldAsk(feedCount: 24), isFalse);
    expect(service.shouldAsk(feedCount: 25), isTrue);
  });

  test('never asks again once the question has been answered', () async {
    expect(service.shouldAsk(feedCount: 200), isTrue);
    await service.settle();
    expect(service.shouldAsk(feedCount: 200), isFalse);
  });

  test('holds its tongue for months after asking', () async {
    await service.recordAsked(feedCount: 30);
    expect(service.shouldAsk(feedCount: 60), isFalse,
        reason: 'inside the quiet period, however many feeds since');
  });

  test('a second ask needs real new usage, not just a lapsed timer', () async {
    final longAgo = DateTime.now()
        .subtract(const Duration(days: 200))
        .millisecondsSinceEpoch;
    await reset({
      'review_ask_count': 1,
      'review_last_asked_at': longAgo,
      'review_feeds_at_last_ask': 100,
    });

    expect(service.shouldAsk(feedCount: 110), isFalse,
        reason: 'barely used since the last ask — asking again is nagging');
    expect(service.shouldAsk(feedCount: 130), isTrue,
        reason: 'a whole new stretch of use earns one more ask');
  });

  test('gives up after two asks', () async {
    final longAgo = DateTime.now()
        .subtract(const Duration(days: 200))
        .millisecondsSinceEpoch;
    await reset({
      'review_ask_count': 2,
      'review_last_asked_at': longAgo,
      'review_feeds_at_last_ask': 100,
    });

    expect(service.shouldAsk(feedCount: 500), isFalse);
  });
}
