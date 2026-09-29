import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether this is a fair moment to ask how the app is going.
///
/// Asking for a rating is a favour, so the rules here are deliberately
/// stricter than Apple's own limiter (three prompts a year). A caregiver has
/// to have actually lived with the app — a week of feeds, not a first night —
/// and the ask only ever rides on top of a moment that already went well.
///
/// Every decision is local to the device. Nothing about sentiment is synced,
/// shared with the household, or attached to the caregiver's record.
class ReviewPromptService {
  ReviewPromptService._();
  static final instance = ReviewPromptService._();

  static const _kFeedsAtLastAsk = 'review_feeds_at_last_ask';
  static const _kLastAskedAt = 'review_last_asked_at';
  static const _kAskCount = 'review_ask_count';
  static const _kSettled = 'review_settled';

  /// Enough logged feeds that the app has genuinely been part of their week.
  static const _minFeeds = 25;

  /// How long to wait after an ask before the next one is even considered.
  static const _quietPeriod = Duration(days: 120);

  /// Two asks, ever. If they haven't rated after the second, they've answered.
  static const _maxAsks = 2;

  SharedPreferences? _prefs;

  /// Always re-reads rather than caching on first call: the plugin already
  /// returns a shared instance, and holding the first one forever makes the
  /// gate impossible to exercise in tests.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Whether a delight moment should carry the "how's it going?" question.
  ///
  /// [feedCount] is the household's lifetime logged feeds — the closest thing
  /// to a measure of whether the app earned the right to ask.
  bool shouldAsk({required int feedCount}) {
    final prefs = _prefs;
    if (prefs == null) return false;

    // They rated, or told us how they felt and we acted on it. Done asking.
    if (prefs.getBool(_kSettled) ?? false) return false;

    if ((prefs.getInt(_kAskCount) ?? 0) >= _maxAsks) return false;
    if (feedCount < _minFeeds) return false;

    final lastAsked = prefs.getInt(_kLastAskedAt);
    if (lastAsked != null) {
      final since = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastAsked));
      if (since < _quietPeriod) return false;

      // A second ask has to be backed by real new usage, not just a lapsed
      // timer — otherwise it's the same question to someone who ignored it.
      final feedsThen = prefs.getInt(_kFeedsAtLastAsk) ?? 0;
      if (feedCount - feedsThen < _minFeeds) return false;
    }

    return true;
  }

  /// Records that the question was put to them, whatever they answer next.
  Future<void> recordAsked({required int feedCount}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt(_kAskCount, (prefs.getInt(_kAskCount) ?? 0) + 1);
    await prefs.setInt(_kLastAskedAt, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_kFeedsAtLastAsk, feedCount);
  }

  /// They're happy, or they took the time to write to us. Either way the
  /// question has been answered and shouldn't come back.
  Future<void> settle() async => _prefs?.setBool(_kSettled, true);

  /// Hands off to the system rating sheet.
  ///
  /// iOS decides whether to actually show it — it may silently do nothing if
  /// the device has already seen it recently. Nothing here depends on it
  /// appearing, and the caregiver is never told a sheet is coming.
  Future<void> openSystemReviewSheet() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}
