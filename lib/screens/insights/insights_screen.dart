import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../build_flags.dart';
import '../../data/app_state.dart';
import '../../models/insights.dart';
import '../../models/mascots.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';
import '../share/share_card_screen.dart';
import 'feed_heatmap.dart';

/// Insights: the long view of a household's feeding rhythm. Two pieces do the
/// emotional work — the day-rhythm heatmap (watch the night hours go quiet)
/// and Livy's weekly digest (what actually changed, in her voice).
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _windowDays = 14;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bundle = app.bundle;
    if (bundle == null) return const SizedBox.shrink();

    final window = app.rollupWindow(days: _windowDays);
    final digest = app.weeklyDigest;
    final totalLogged = window.fold<int>(0, (s, r) => s + r.count);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
        children: [
          const SizedBox(height: LivySpace.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insights', style: LivyType.display(size: 30)),
                    Text(
                      'How ${bundle.household.baby.name}\'s rhythm is changing',
                      style: LivyType.body(size: 13, color: LivyColors.mist),
                    ),
                  ],
                ),
              ),
              if (app.isDemo && !kScreenshotMode) const DemoBadge(),
            ],
          ),

          if (totalLogged == 0) ...[
            const SizedBox(height: LivySpace.xxl),
            _EmptyState(mascot: app.mascot, mascotName: app.mascotName),
          ] else ...[
            // ── Livy's weekly digest ──────────────────────────────────────
            if (digest != null) ...[
              const SectionHeader('This week with Livy'),
              _DigestCard(digest: digest)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.08),
            ],

            // ── Day-rhythm heatmap ────────────────────────────────────────
            SectionHeader(
              'Day rhythm',
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 14, label: Text('14d')),
                  ButtonSegment(value: 28, label: Text('28d')),
                ],
                selected: {_windowDays},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _windowDays = s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(LivyType.body(size: 11)),
                  side: WidgetStatePropertyAll(
                      BorderSide(color: LivyColors.outline)),
                ),
              ),
            ),
            VoxelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every feed, placed by the hour it happened.',
                    style: LivyType.body(size: 13, color: LivyColors.mist),
                  ),
                  const SizedBox(height: LivySpace.md),
                  FeedHeatmap(days: window),
                ],
              ),
            ),
            if (digest != null) _NightTrendNote(digest: digest),

            // ── Supporting numbers ────────────────────────────────────────
            const SectionHeader('At a glance'),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'FEEDS · ${_windowDays}D',
                    value: totalLogged,
                  ),
                ),
                const SizedBox(width: LivySpace.sm),
                Expanded(
                  child: StatTile(
                    label: 'AVG / DAY',
                    value: (totalLogged / _windowDays),
                    accent: LivyColors.mint,
                  ),
                ),
                const SizedBox(width: LivySpace.sm),
                Expanded(
                  child: StatTile(
                    label: 'NIGHT FEEDS',
                    value: window.fold<int>(0, (s, r) => s + r.nightFeeds),
                    accent: LivyColors.periwinkle,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }
}

// ── Weekly digest ───────────────────────────────────────────────────────────

class _DigestCard extends StatelessWidget {
  const _DigestCard({required this.digest});

  final WeeklyDigest digest;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = digest;

    return VoxelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MascotView(
                  mascot: app.mascot,
                  pose: MascotPose.thoughtful,
                  size: 56,
                  glow: false),
              const SizedBox(width: LivySpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${app.mascotName}\'s week in review',
                        style: LivyType.label(color: LivyColors.amber)),
                    const SizedBox(height: 2),
                    Text(
                      _headline(d, app),
                      style: LivyType.body(size: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: LivySpace.md),
          Wrap(
            spacing: LivySpace.sm,
            runSpacing: LivySpace.sm,
            children: [
              _DeltaChip(
                label: 'feeds',
                value: '${d.feeds}',
                delta: d.hasPreviousWeek ? d.feedsDelta.toDouble() : null,
                unit: '',
              ),
              _DeltaChip(
                label: 'avg per feed',
                value: app.formatAmount(d.avgMl),
                delta: d.hasPreviousWeek ? d.avgMlDelta : null,
                unit: ' mL',
                decimals: 0,
              ),
              _DeltaChip(
                label: 'night feeds',
                value: '${d.nightFeeds}',
                delta: d.hasPreviousWeek ? d.nightFeedsDelta.toDouble() : null,
                unit: '',
                // Fewer night feeds is the good direction here.
                lowerIsBetter: true,
              ),
              if (d.avgIntervalMinutes > 0)
                _DeltaChip(
                  label: 'between feeds',
                  value: _fmtInterval(d.avgIntervalMinutes),
                  delta: d.hasPreviousWeek ? d.intervalDeltaMinutes : null,
                  unit: 'm',
                  decimals: 0,
                ),
            ],
          ),
          if (d.caregiverSplit.length > 1) ...[
            const SizedBox(height: LivySpace.md),
            _TagTeamBar(split: d.caregiverSplit),
          ],
          const SizedBox(height: LivySpace.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ShareCardScreen())),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Share this week'),
            ),
          ),
        ],
      ),
    );
  }

  /// Livy's read on the week — warm, specific, never prescriptive.
  static String _headline(WeeklyDigest d, AppState app) {
    if (!d.hasPreviousWeek) {
      return 'Your first week of records — ${d.feeds} feeds logged together. '
          'I\'ll start noticing patterns as the weeks stack up.';
    }
    if (d.nightFeedsDelta < 0) {
      final fewer = -d.nightFeedsDelta;
      return '$fewer fewer night feed${fewer == 1 ? '' : 's'} than last week. '
          'Slowly but surely, the nights are getting their quiet back.';
    }
    if (d.intervalDeltaMinutes > 10) {
      return 'Feeds stretched about ${d.intervalDeltaMinutes.round()} minutes '
          'further apart this week — a very ordinary sign of growing.';
    }
    if (d.avgMlDelta > 5) {
      return 'Bottles are running a little fuller this week. Appetites grow '
          'right along with the baby.';
    }
    return '${d.feeds} feeds, steady as a metronome. Consistency like this is '
        'its own kind of achievement.';
  }

  static String _fmtInterval(double minutes) {
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return h == 0 ? '${m}m' : '${h}h ${m.toString().padLeft(2, '0')}';
  }
}

/// A stat with its week-over-week change, colored by whether the direction is
/// the encouraging one.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.value,
    required this.delta,
    this.unit = '',
    this.decimals = 0,
    this.lowerIsBetter = false,
  });

  final String label;
  final String value;
  final double? delta;
  final String unit;
  final int decimals;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final flat = d == null || d.abs() < 0.5;
    final good = d == null ? false : (lowerIsBetter ? d < 0 : d > 0);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: LivySpace.md, vertical: LivySpace.sm),
      decoration: BoxDecoration(
        color: LivyColors.surfaceSunken,
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        border: Border.all(color: LivyColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: LivyType.label(size: 9)),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: LivyType.data(size: 18, weight: FontWeight.w700)),
              if (!flat) ...[
                const SizedBox(width: 6),
                Icon(
                  d > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: good ? LivyColors.mint : LivyColors.butter,
                ),
                Text(
                  '${d.abs().toStringAsFixed(decimals)}$unit',
                  style: LivyType.body(
                      size: 11,
                      color: good ? LivyColors.mint : LivyColors.butter),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Who covered how much — framed as teamwork, never as a scoreboard.
class _TagTeamBar extends StatelessWidget {
  const _TagTeamBar({required this.split});

  final Map<String, int> split;

  // Resolved at call time — palette colors change with the theme phase.
  static List<Color> get _colors => [
        LivyColors.amber,
        LivyColors.coral,
        LivyColors.mint,
        LivyColors.periwinkle,
        LivyColors.butter,
      ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = split.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SHARED BETWEEN YOU', style: LivyType.label(size: 9)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(LivyRadius.pill),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++)
                  Expanded(
                    flex: entries[i].value,
                    child: Container(color: _colorAt(i)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: LivySpace.md,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                        color: _colorAt(i), shape: BoxShape.circle),
                  ),
                  Text(
                    '${app.caregiverNameFor(entries[i].key)} · '
                    '${entries[i].value}',
                    style: LivyType.body(size: 12, color: LivyColors.mist),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  static Color _colorAt(int i) => _colors[i % _colors.length];
}

/// The headline the heatmap is really about: are the nights getting quieter?
class _NightTrendNote extends StatelessWidget {
  const _NightTrendNote({required this.digest});

  final WeeklyDigest digest;

  @override
  Widget build(BuildContext context) {
    if (!digest.hasPreviousWeek || digest.nightFeedsDelta == 0) {
      return const SizedBox.shrink();
    }
    final fewer = digest.nightFeedsDelta < 0;
    final n = digest.nightFeedsDelta.abs();

    return Padding(
      padding: const EdgeInsets.only(top: LivySpace.sm),
      child: Row(
        children: [
          Icon(
            fewer ? Icons.nightlight_round : Icons.bedtime_outlined,
            size: 14,
            color: fewer ? LivyColors.mint : LivyColors.mist,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fewer
                  ? '$n fewer night feed${n == 1 ? '' : 's'} than last week.'
                  : '$n more night feed${n == 1 ? '' : 's'} than last week — '
                      'growth spurts do this.',
              style: LivyType.body(size: 12, color: LivyColors.mist),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mascot, required this.mascotName});

  final MascotDef mascot;
  final String mascotName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MascotView(mascot: mascot, pose: MascotPose.thoughtful, size: 140),
        const SizedBox(height: LivySpace.lg),
        Text('Not much to read yet',
            textAlign: TextAlign.center, style: LivyType.display(size: 22)),
        const SizedBox(height: LivySpace.sm),
        Text(
          'Log a few feeds and $mascotName will start showing you the shape of '
          'your days — including how the night hours change as your little one '
          'grows.',
          textAlign: TextAlign.center,
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
      ],
    );
  }
}
