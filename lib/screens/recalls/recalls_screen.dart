import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// FDA recall alerts, matched to the household's logged formula brands, with
/// a clear "last checked" timestamp. Backed by the swappable RecallDataSource
/// (live openFDA enforcement reports; sample data offline in demo mode).
class RecallsScreen extends StatefulWidget {
  const RecallsScreen({super.key});

  @override
  State<RecallsScreen> createState() => _RecallsScreenState();
}

class _RecallsScreenState extends State<RecallsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await context.read<AppState>().refreshRecalls();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final relevant = app.relevantRecalls;
    final others = app.recallService.all
        .where((n) => !relevant.any((r) => r.id == n.id))
        .toList();
    final lastChecked = app.recallService.lastChecked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recall alerts'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: LivyColors.mist))
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: LivyColors.amber,
        backgroundColor: LivyColors.surfaceRaised,
        child: ListView(
          padding: const EdgeInsets.all(LivySpace.lg),
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: LivyColors.mint),
                const SizedBox(width: LivySpace.sm),
                Text(
                  lastChecked == null
                      ? 'Checking…'
                      : 'Last checked ${DateFormat('MMM d, h:mm a').format(lastChecked)}',
                  style: LivyType.body(size: 12, color: LivyColors.mist),
                ),
                if (app.isDemo) ...[
                  const Spacer(),
                  const DemoBadge(),
                ],
              ],
            ),
            const SizedBox(height: LivySpace.md),
            if (relevant.isEmpty)
              VoxelCard(
                color: LivyColors.mint.withValues(alpha: 0.07),
                borderColor: LivyColors.mint.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    Image.asset(MascotAssetResolver.instance.adaptive('assets/icons/icon_shield.png'),
                        width: 54,
                        errorBuilder: (_, _, _) => Icon(Icons.shield_outlined,
                            color: LivyColors.mint, size: 40)),
                    const SizedBox(width: LivySpace.md),
                    Expanded(
                      child: Text(
                        'No active notices match the formulas in your log '
                        '(${app.loggedBrands.isEmpty ? 'none logged yet' : app.loggedBrands.join(', ')}).',
                        style: LivyType.body(size: 14),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text('MATCHES YOUR FORMULA', style: LivyType.label(color: LivyColors.rose)),
              const SizedBox(height: LivySpace.sm),
              for (final n in relevant) _RecallCard(notice: n, relevant: true),
            ],
            if (others.isNotEmpty) ...[
              const SectionHeader('Other current notices'),
              for (final n in others) _RecallCard(notice: n, relevant: false),
            ],
            const SizedBox(height: LivySpace.md),
            Text(
              'Recall notices come from the U.S. FDA\'s public enforcement reports '
              '(openFDA) and may lag official announcements. Always check fda.gov and '
              'the product packaging directly if you suspect a recall.',
              style: LivyType.body(size: 11, color: LivyColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecallCard extends StatelessWidget {
  const _RecallCard({required this.notice, required this.relevant});

  final RecallNotice notice;
  final bool relevant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LivySpace.sm),
      child: VoxelCard(
        borderColor:
            relevant ? LivyColors.rose.withValues(alpha: 0.45) : LivyColors.outline,
        color: relevant ? LivyColors.rose.withValues(alpha: 0.06) : LivyColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(notice.brand,
                        style: LivyType.body(size: 15, weight: FontWeight.w700))),
                Text(DateFormat('MMM d').format(notice.publishedAt),
                    style: LivyType.body(size: 12, color: LivyColors.faint)),
              ],
            ),
            const SizedBox(height: 2),
            Text(notice.title, style: LivyType.body(size: 13, color: LivyColors.rose)),
            const SizedBox(height: LivySpace.sm),
            Text(notice.summary, style: LivyType.body(size: 13, color: LivyColors.mist)),
            if (notice.lotCodes.isNotEmpty) ...[
              const SizedBox(height: LivySpace.sm),
              Wrap(
                spacing: LivySpace.xs,
                runSpacing: LivySpace.xs,
                children: notice.lotCodes
                    .map((c) => Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: LivyColors.surfaceSunken,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: LivyColors.outline),
                          ),
                          child: Text('Lot $c', style: LivyType.data(size: 11)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
