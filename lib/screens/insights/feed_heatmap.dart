import 'package:flutter/material.dart';

import '../../models/insights.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';

/// The day-rhythm heatmap: one row per day, 24 columns for hours. Warmer,
/// brighter cells mean more feeds started in that hour.
///
/// The whole point is watching the left and right edges (the night hours) go
/// quiet as the baby grows — so the night band is tinted and labelled rather
/// than left for the reader to find.
class FeedHeatmap extends StatelessWidget {
  const FeedHeatmap({super.key, required this.days});

  /// Oldest first, one entry per day, gaps included.
  final List<DailyRollup> days;

  static const _nightHours = {22, 23, 0, 1, 2, 3, 4, 5};

  @override
  Widget build(BuildContext context) {
    final peak = days
        .expand((d) => d.hourCounts.values)
        .fold<int>(1, (m, v) => v > m ? v : m);

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelWidth = 30.0;
        const gap = 1.5;
        final cell =
            ((constraints.maxWidth - labelWidth) - gap * 23) / 24;
        final cellH = cell.clamp(9.0, 14.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hour ruler.
            Padding(
              padding: const EdgeInsets.only(left: labelWidth, bottom: 6),
              child: SizedBox(
                height: 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final h in const [0, 6, 12, 18])
                      Positioned(
                        left: h * (cell + gap),
                        child: Text(
                          switch (h) {
                            0 => '12a',
                            6 => '6a',
                            12 => '12p',
                            _ => '6p',
                          },
                          style: LivyType.label(size: 9, color: LivyColors.faint),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        _dayLabel(day.day),
                        style: LivyType.label(
                          size: 9,
                          color: _isToday(day.day)
                              ? LivyColors.amber
                              : LivyColors.faint,
                        ),
                      ),
                    ),
                    for (var h = 0; h < 24; h++) ...[
                      _Cell(
                        count: day.hourCounts[h] ?? 0,
                        peak: peak,
                        night: _nightHours.contains(h),
                        width: cell,
                        height: cellH,
                      ),
                      if (h < 23) const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: LivySpace.sm),
            _Legend(peak: peak),
          ],
        );
      },
    );
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _dayLabel(DateTime d) {
    const names = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return names[d.weekday - 1];
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.count,
    required this.peak,
    required this.night,
    required this.width,
    required this.height,
  });

  final int count;
  final int peak;
  final bool night;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = peak == 0 ? 0.0 : (count / peak).clamp(0.0, 1.0);
    final empty = count == 0;

    // Night hours sit on a slightly sunken ground and fill toward periwinkle;
    // daytime hours fill toward amber. Same data, readable at a glance.
    final base = night
        ? LivyColors.surfaceSunken
        : LivyColors.surfaceSunken.withValues(alpha: 0.55);
    final full = night ? LivyColors.periwinkle : LivyColors.amber;

    return Tooltip(
      message: count == 0 ? '' : '$count feed${count == 1 ? '' : 's'}',
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: empty
              ? base
              : Color.lerp(full.withValues(alpha: 0.22), full, t),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.peak});

  final int peak;

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, double alpha) => Container(
          width: 11,
          height: 11,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: c.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Row(
      children: [
        Text('Night', style: LivyType.label(size: 9, color: LivyColors.faint)),
        const SizedBox(width: 6),
        swatch(LivyColors.periwinkle, 0.3),
        swatch(LivyColors.periwinkle, 1),
        const SizedBox(width: LivySpace.md),
        Text('Day', style: LivyType.label(size: 9, color: LivyColors.faint)),
        const SizedBox(width: 6),
        swatch(LivyColors.amber, 0.3),
        swatch(LivyColors.amber, 1),
        const Spacer(),
        Text('busiest hour: $peak',
            style: LivyType.label(size: 9, color: LivyColors.faint)),
      ],
    );
  }
}
