import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/health_sources.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/citations.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';
import '../schedule/schedule_screen.dart';

/// Livy's recommendation feed — visually and textually distinct from log
/// data, never prescriptive, always ending with the pediatrician line.
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final recs = [...?app.bundle?.recommendations]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = recs.where((r) => !r.dismissed).toList();
    final past = recs.where((r) => r.dismissed).toList();

    return Scaffold(
      appBar: AppBar(title: Text("${app.mascotName}'s recommendations")),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          VoxelCard(
            color: LivyColors.surfaceSunken,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These are gentle observations from your own feeding log, grounded in '
                  'general pediatric guidance — never a diagnosis or an instruction. '
                  'The schedule only changes when you change it.',
                  style: LivyType.body(size: 13, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.sm),
                // The "general pediatric guidance" named above, cited.
                const InlineCitations(HealthSources.bottleFeeding),
              ],
            ),
          ),
          if (active.isEmpty && past.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: LivySpace.xxl),
              child: Column(
                children: [
                  MascotView(mascot: app.mascot, pose: MascotPose.sleepy, size: 140),
                  const SizedBox(height: LivySpace.md),
                  Text('All quiet', style: LivyType.display(size: 20)),
                  Text(
                    '${app.mascotName} will pipe up when the pattern has something to say.',
                    textAlign: TextAlign.center,
                    style: LivyType.body(color: LivyColors.mist),
                  ),
                ],
              ),
            ),
          for (final r in active) _RecCard(rec: r),
          if (past.isNotEmpty) ...[
            const SectionHeader('Earlier'),
            for (final r in past) Opacity(opacity: 0.55, child: _RecCard(rec: r, readOnly: true)),
          ],
          const DisclaimerFooter(),
        ],
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, this.readOnly = false});

  final LivyRecommendation rec;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(top: LivySpace.md),
      child: RecommendationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEE, MMM d').format(rec.createdAt),
                style: LivyType.label(size: 10, color: LivyColors.amber)),
            const SizedBox(height: LivySpace.xs),
            Text(rec.text, style: LivyType.body(size: 14)),
            if (!readOnly)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => app.dismissRecommendation(rec),
                    child: Text('Dismiss',
                        style: LivyType.body(size: 14, color: LivyColors.mist)),
                  ),
                  if (rec.kind == RecommendationKind.intervalDrift)
                    TextButton(
                      onPressed: () {
                        app.actOnRecommendation(rec);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ScheduleScreen()));
                      },
                      child: const Text('Review schedule'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
