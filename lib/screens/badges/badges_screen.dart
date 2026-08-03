import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/badge_catalog.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/celebration_overlay.dart';
import '../../widgets/common.dart';
import '../share/share_card_screen.dart';

/// Streaks, the badge catalog, and the one streak-freeze. Both being on time
/// and logging consistently are celebrated equally — plus the tag-team track.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final bundle = app.bundle;
    if (bundle == null) return const SizedBox.shrink();

    final tracks = [
      (BadgeTrack.onTime, 'Fed on time', LivyColors.amber),
      (BadgeTrack.logging, 'Every feed logged', LivyColors.mint),
      (BadgeTrack.tagTeam, 'Tag-team', LivyColors.coral),
      (BadgeTrack.milestone, 'Milestones', LivyColors.periwinkle),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
        children: [
          const SizedBox(height: LivySpace.md),
          Row(
            children: [
              Expanded(child: Text('Badges', style: LivyType.display(size: 30))),
              IconButton(
                tooltip: 'Share a milestone card',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShareCardScreen())),
                icon: Icon(Icons.ios_share_rounded, color: LivyColors.periwinkle),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      label: 'BEST ON-TIME',
                      value: bundle.streaks.bestOnTimeStreak,
                      suffix: 'd',
                      accent: LivyColors.amber)),
              const SizedBox(width: LivySpace.sm),
              Expanded(
                  child: StatTile(
                      label: 'BEST LOGGING',
                      value: bundle.streaks.bestLoggingStreak,
                      suffix: 'd',
                      accent: LivyColors.mint)),
              const SizedBox(width: LivySpace.sm),
              Expanded(
                  child: StatTile(
                      label: 'TOTAL FEEDS',
                      value: bundle.feeds.length,
                      accent: LivyColors.periwinkle)),
            ],
          ),
          const SizedBox(height: LivySpace.md),
          VoxelCard(
            child: Row(
              children: [
                Icon(
                  bundle.streaks.freezeAvailable
                      ? Icons.ac_unit_rounded
                      : Icons.check_circle_outline_rounded,
                  color: LivyColors.periwinkle,
                ),
                const SizedBox(width: LivySpace.md),
                Expanded(
                  child: Text(
                    bundle.streaks.freezeAvailable
                        ? 'One streak-freeze available — a rough day won\'t break the streak.'
                        : 'Streak-freeze used${bundle.streaks.freezeUsedAt != null ? ' on ${DateFormat('MMM d').format(bundle.streaks.freezeUsedAt!)}' : ''} — it forgave a missed day.',
                    style: LivyType.body(size: 13, color: LivyColors.mist),
                  ),
                ),
              ],
            ),
          ),
          for (final (track, title, color) in tracks) ...[
            SectionHeader(title),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: LivySpace.sm,
              crossAxisSpacing: LivySpace.sm,
              childAspectRatio: 0.78,
              children: [
                for (final def in BadgeCatalog.all.where((b) => b.track == track))
                  _BadgeCell(def: def, accent: color),
              ],
            ),
          ],
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({required this.def, required this.accent});

  final BadgeDef def;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final unlock =
        app.bundle?.badges.where((b) => b.badgeId == def.id).firstOrNull;
    final unlocked = unlock != null;

    return VoxelCard(
      padding: const EdgeInsets.all(LivySpace.sm),
      borderColor: unlocked ? accent.withValues(alpha: 0.5) : LivyColors.outline,
      onTap: () {
        if (unlocked) {
          showBadgeCelebration(context,
              badge: def, mascot: app.mascot, mascotName: app.mascotName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_lockedHint(def), style: LivyType.body(size: 13)),
          ));
        }
      },
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LivyRadius.sm),
              child: ColorFiltered(
                colorFilter: unlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0, //
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 0.35, 0,
                      ]),
                child: Image.asset(
                  def.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: LivyColors.surfaceSunken,
                    child: Icon(Icons.emoji_events_rounded,
                        color: unlocked ? accent : LivyColors.faint, size: 34),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            def.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: LivyType.body(
                size: 11,
                weight: FontWeight.w700,
                color: unlocked ? LivyColors.cream : LivyColors.faint),
          ),
        ],
      ),
    ).animate(target: unlocked ? 1 : 0).shimmer(
        duration: 1800.ms, color: accent.withValues(alpha: 0.25), delay: 600.ms);
  }

  String _lockedHint(BadgeDef def) => switch (def.track) {
        BadgeTrack.onTime => 'Keep feeds on schedule for ${def.threshold} days to unlock.',
        BadgeTrack.logging => 'Log every feed for ${def.threshold} days to unlock.',
        BadgeTrack.tagTeam => def.threshold == 1
            ? 'Two caregivers logging back-to-back feeds unlocks this.'
            : 'Tag-team for ${def.threshold} days straight to unlock.',
        BadgeTrack.milestone => 'Log ${def.threshold} feeds together to unlock.',
      };
}
