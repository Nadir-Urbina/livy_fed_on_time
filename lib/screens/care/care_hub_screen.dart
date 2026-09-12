import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';
import '../caregivers/caregivers_screen.dart';
import '../guide/pediatrician_guide_screen.dart';
import '../guide/recommendations_screen.dart';
import '../journal/formula_journal_screen.dart';
import '../guide/sources_screen.dart';
import '../recalls/recalls_screen.dart';
import '../settings/settings_screen.dart';

/// Care hub: everything beyond the nightly loop — Livy's recommendations,
/// the pediatrician visit guide, formula journal, recall alerts, caregivers,
/// and settings.
class CareHubScreen extends StatelessWidget {
  const CareHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final activeRecs =
        app.bundle?.recommendations.where((r) => !r.dismissed).length ?? 0;
    final recalls = app.relevantRecalls.length;
    final caregivers = app.bundle?.household.caregivers.length ?? 1;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
        children: [
          const SizedBox(height: LivySpace.md),
          Row(
            children: [
              Expanded(child: Text('Care', style: LivyType.display(size: 30))),
              MascotView(mascot: app.mascot, pose: MascotPose.thoughtful, size: 64, glow: false),
            ],
          ),
          const SizedBox(height: LivySpace.md),
          _HubTile(
            icon: Icons.tips_and_updates_outlined,
            color: LivyColors.amber,
            title: "${app.mascotName}'s recommendations",
            subtitle: activeRecs > 0
                ? '$activeRecs gentle ${activeRecs == 1 ? 'nudge' : 'nudges'} waiting'
                : 'Nothing new — all calm',
            badgeCount: activeRecs,
            builder: (_) => const RecommendationsScreen(),
          ),
          _HubTile(
            icon: Icons.medical_information_outlined,
            color: LivyColors.mint,
            title: 'Pediatrician visit guide',
            subtitle: 'Turn symptom notes into talking points',
            builder: (_) => const PediatricianGuideScreen(),
          ),
          _HubTile(
            icon: Icons.swap_horiz_rounded,
            color: LivyColors.periwinkle,
            title: 'Formula journal',
            subtitle: 'Every switch, and how it went',
            builder: (_) => const FormulaJournalScreen(),
          ),
          _HubTile(
            icon: Icons.gpp_maybe_outlined,
            color: LivyColors.rose,
            title: 'Recall alerts',
            subtitle: recalls > 0
                ? '$recalls ${recalls == 1 ? 'notice' : 'notices'} match your formula'
                : 'No notices match your formula',
            badgeCount: recalls,
            builder: (_) => const RecallsScreen(),
          ),
          _HubTile(
            icon: Icons.group_outlined,
            color: LivyColors.coral,
            title: 'Caregivers',
            subtitle: '$caregivers of 5 household seats in use',
            builder: (_) => const CaregiversScreen(),
          ),
          _HubTile(
            icon: Icons.menu_book_outlined,
            color: LivyColors.butter,
            title: 'Sources & references',
            subtitle: 'Where Livy\'s general guidance comes from',
            builder: (_) => const SourcesScreen(),
          ),
          _HubTile(
            icon: Icons.tune_rounded,
            color: LivyColors.mist,
            title: 'Mascot & settings',
            subtitle: 'Rename ${app.mascotName}, pick a new companion',
            builder: (_) => const SettingsScreen(),
          ),
          const DisclaimerFooter(),
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.badgeCount = 0,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LivySpace.sm),
      child: VoxelCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: builder)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(LivyRadius.sm),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: LivySpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LivyType.body(size: 15, weight: FontWeight.w700)),
                  Text(subtitle, style: LivyType.body(size: 12, color: LivyColors.mist)),
                ],
              ),
            ),
            if (badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: LivySpace.sm),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(LivyRadius.pill),
                ),
                child: Text('$badgeCount', style: LivyType.data(size: 13, color: color)),
              ),
            Icon(Icons.chevron_right_rounded, color: LivyColors.faint),
          ],
        ),
      ),
    );
  }
}
