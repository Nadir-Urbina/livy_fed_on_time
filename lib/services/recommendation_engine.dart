import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../models/models.dart';

/// Livy's gentle, never-prescriptive nudges. Grounded in general pediatric
/// guidance patterns (intervals stretch and amounts rise as babies grow);
/// every message is clearly a recommendation, never a diagnosis or an
/// instruction, and always ends with the pediatrician disclaimer.
class RecommendationEngine {
  static const _minFeedsForAnalysis = 20;
  static const _cooldown = Duration(days: 3);

  /// Returns a new recommendation to surface, or null. Called after feed logs;
  /// at most one new recommendation per kind per cooldown window.
  static LivyRecommendation? evaluate(HouseholdBundle bundle) {
    final feeds = [...bundle.feeds]..sort((a, b) => a.time.compareTo(b.time));
    if (feeds.length < _minFeedsForAnalysis) return null;

    final now = DateTime.now();
    bool recentlyRaised(RecommendationKind kind) => bundle.recommendations.any(
        (r) => r.kind == kind && now.difference(r.createdAt) < _cooldown);

    final drift = _intervalDrift(feeds, bundle.household.schedule);
    if (drift != null && !recentlyRaised(RecommendationKind.intervalDrift)) {
      return LivyRecommendation(
        id: const Uuid().v4(),
        kind: RecommendationKind.intervalDrift,
        text: drift,
        createdAt: now,
      );
    }

    final amount = _amountTrend(feeds);
    if (amount != null && !recentlyRaised(RecommendationKind.amountTrend)) {
      return LivyRecommendation(
        id: const Uuid().v4(),
        kind: RecommendationKind.amountTrend,
        text: amount,
        createdAt: now,
      );
    }

    return null;
  }

  static String _fmtInterval(double minutes) {
    final h = minutes / 60;
    final rounded = (h * 4).round() / 4; // quarter-hour granularity
    return rounded == rounded.roundToDouble()
        ? 'every ${rounded.round()}h'
        : 'every ${rounded.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')}h';
  }

  /// Detects the natural stretch of feeding intervals vs. the set schedule.
  static String? _intervalDrift(List<Feed> feeds, FeedingSchedule schedule) {
    final recent = feeds.length > 30 ? feeds.sublist(feeds.length - 30) : feeds;
    final gaps = <double>[];
    for (var i = 1; i < recent.length; i++) {
      final g = recent[i].time.difference(recent[i - 1].time).inMinutes.toDouble();
      // Ignore overnight long stretches; they'd skew the average.
      if (g > 30 && g < 8 * 60) gaps.add(g);
    }
    if (gaps.length < 10) return null;
    final avg = gaps.reduce((a, b) => a + b) / gaps.length;
    final scheduled = schedule.intervalMinutes.toDouble();
    if ((avg - scheduled).abs() < 20) return null;
    final direction = avg > scheduled ? 'stretched' : 'tightened';
    return 'Feeds have naturally $direction to about ${_fmtInterval(avg)} this week, while the '
        'schedule is set to ${schedule.intervalLabel}. This drift is common as babies grow — '
        'if it keeps up, you may want to update the schedule together. '
        '${LivyRecommendation.disclaimer}';
  }

  /// Notices a sustained rise (or dip) in amounts per feed.
  static String? _amountTrend(List<Feed> feeds) {
    if (feeds.length < 30) return null;
    final older = feeds.sublist(feeds.length - 30, feeds.length - 15);
    final newer = feeds.sublist(feeds.length - 15);
    double avg(List<Feed> l) => l.map((f) => f.amountMl).reduce((a, b) => a + b) / l.length;
    final a0 = avg(older), a1 = avg(newer);
    if (a0 <= 0) return null;
    final change = (a1 - a0) / a0;
    if (change > 0.12) {
      return 'Amounts have been trending up lately (about ${a0.round()} mL → ${a1.round()} mL '
          'per feed). This can be perfectly normal as babies grow. '
          '${LivyRecommendation.disclaimer}';
    }
    if (change < -0.15) {
      return 'Amounts have dipped a little recently (about ${a0.round()} mL → ${a1.round()} mL '
          'per feed). Appetites naturally ebb and flow — it may be worth keeping a gentle eye on. '
          '${LivyRecommendation.disclaimer}';
    }
    return null;
  }
}
