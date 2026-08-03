import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Shared feed history — identical for every caregiver the instant a feed is
/// logged — plus simple trend views (feeds/day, average amount, interval
/// drift) so patterns become visible as the baby grows.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bundle = app.bundle;
    if (bundle == null) return const SizedBox.shrink();

    final feeds = bundle.feeds;
    final byDay = <DateTime, List<Feed>>{};
    for (final f in feeds) {
      final day = DateTime(f.time.year, f.time.month, f.time.day);
      byDay.putIfAbsent(day, () => []).add(f);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
        children: [
          const SizedBox(height: LivySpace.md),
          Row(
            children: [
              Expanded(child: Text('History', style: LivyType.display(size: 30))),
              IconButton(
                tooltip: 'Toggle mL / oz',
                onPressed: app.toggleUnits,
                icon: Text(app.useMetric ? 'mL' : 'oz',
                    style: LivyType.data(size: 14, color: LivyColors.periwinkle)),
              ),
            ],
          ),
          _TrendsCard(app: app),
          if (feeds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: LivySpace.xxl),
              child: Column(
                children: [
                  Image.asset(MascotAssetResolver.instance.adaptive('assets/icons/icon_bottle.png'),
                      width: 120,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.water_drop, size: 60, color: LivyColors.faint)),
                  const SizedBox(height: LivySpace.md),
                  Text('No feeds yet',
                      textAlign: TextAlign.center, style: LivyType.display(size: 20)),
                  Text('The first log starts the story.',
                      textAlign: TextAlign.center,
                      style: LivyType.body(color: LivyColors.mist)),
                ],
              ),
            ),
          for (final day in days) ...[
            SectionHeader(_dayLabel(day),
                trailing: Text(
                  '${byDay[day]!.length} feeds · '
                  '${app.formatAmount(byDay[day]!.fold(0.0, (s, f) => s + f.amountMl))}',
                  style: LivyType.body(size: 12, color: LivyColors.faint),
                )),
            ...byDay[day]!.map((f) => _FeedRow(feed: f)),
          ],
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }

  String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    if (day == t0) return 'Today';
    if (day == t0.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.feed});

  final Feed feed;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final mine = feed.loggedById == app.caregiverId;
    return Padding(
      padding: const EdgeInsets.only(bottom: LivySpace.sm),
      child: VoxelCard(
        padding: const EdgeInsets.symmetric(
            horizontal: LivySpace.md, vertical: LivySpace.sm + 2),
        onTap: () => _showDetail(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (mine ? LivyColors.amber : LivyColors.coral).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(LivyRadius.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                feed.loggedByName.characters.first.toUpperCase(),
                style: LivyType.data(
                    size: 18,
                    weight: FontWeight.w700,
                    color: mine ? LivyColors.amber : LivyColors.coral),
              ),
            ),
            const SizedBox(width: LivySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormat('h:mm a').format(feed.time)} · ${context.watch<AppState>().formatAmount(feed.amountMl)}',
                    style: LivyType.body(size: 15, weight: FontWeight.w700),
                  ),
                  Text(
                    [
                      feed.loggedByName,
                      if (feed.formulaBrand != null) feed.formulaBrand!,
                      ...feed.symptoms.map((s) => s.kind.label.toLowerCase()),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LivyType.body(size: 12, color: LivyColors.mist),
                  ),
                ],
              ),
            ),
            if (feed.symptoms.isNotEmpty)
              Icon(Icons.sticky_note_2_outlined, size: 18, color: LivyColors.coral),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final app = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(LivySpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, MMM d · h:mm a').format(feed.time),
                style: LivyType.display(size: 20)),
            const SizedBox(height: LivySpace.sm),
            Text('${app.formatAmount(feed.amountMl)} logged by ${feed.loggedByName}',
                style: LivyType.body()),
            if (feed.formulaBrand != null)
              Text('Formula: ${feed.formulaBrand}',
                  style: LivyType.body(color: LivyColors.mist)),
            for (final s in feed.symptoms)
              Padding(
                padding: const EdgeInsets.only(top: LivySpace.xs),
                child: Text(
                    '• ${s.kind.label}${s.note.isNotEmpty ? ' — ${s.note}' : ''}',
                    style: LivyType.body(color: LivyColors.coral)),
              ),
            if (feed.note != null && feed.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: LivySpace.xs),
                child: Text('“${feed.note}”', style: LivyType.body(color: LivyColors.mist)),
              ),
            const SizedBox(height: LivySpace.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  app.deleteFeed(feed.id);
                  Navigator.of(sheetContext).pop();
                },
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: LivyColors.rose),
                label: Text('Remove entry',
                    style: LivyType.body(size: 14, color: LivyColors.rose)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feeds/day bars + average-amount line + interval drift, hand-painted to
/// match the design system.
class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final daily = app.dailyTrend();
    final intervals = app.intervalTrend();
    if (daily.every((d) => d.count == 0)) return const SizedBox.shrink();

    final maxCount =
        daily.map((d) => d.count).fold(1, (a, b) => a > b ? a : b).toDouble();
    final drift = _driftLabel(intervals);

    return VoxelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LAST 7 DAYS', style: LivyType.label()),
          const SizedBox(height: LivySpace.md),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in daily)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (d.count > 0)
                            Text('${d.count}',
                                style: LivyType.data(size: 11, color: LivyColors.mist)),
                          const SizedBox(height: 4),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: d.count / maxCount),
                            duration: LivyMotion.slow,
                            curve: LivyMotion.settle,
                            builder: (context, t, _) => Container(
                              height: 70 * t + 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [LivyColors.amberDeep, LivyColors.amber],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(DateFormat('E').format(d.day).substring(0, 2),
                              style: LivyType.label(size: 9, color: LivyColors.faint)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: LivySpace.lg),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Avg amount',
                  app.formatAmount(_avgAmount(daily)),
                  LivyColors.mint,
                ),
              ),
              Expanded(child: _miniStat('Interval drift', drift, LivyColors.periwinkle)),
              Expanded(
                child: _miniStat(
                  'Feeds today',
                  '${daily.last.count}',
                  LivyColors.coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _avgAmount(List<({DateTime day, int count, double avgMl})> daily) {
    final withData = daily.where((d) => d.count > 0).toList();
    if (withData.isEmpty) return 0;
    return withData.map((d) => d.avgMl).reduce((a, b) => a + b) / withData.length;
  }

  String _driftLabel(List<({DateTime day, double avgGapMinutes})> intervals) {
    final withData = intervals.where((d) => d.avgGapMinutes > 0).toList();
    if (withData.length < 2) return '—';
    final delta = withData.last.avgGapMinutes - withData.first.avgGapMinutes;
    if (delta.abs() < 5) return 'steady';
    final sign = delta > 0 ? '+' : '−';
    return '$sign${delta.abs().round()}m';
  }

  Widget _miniStat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: LivyType.data(size: 16, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: LivyType.label(size: 9)),
        ],
      );
}
