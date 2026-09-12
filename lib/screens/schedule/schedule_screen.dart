import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../data/health_sources.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/citations.dart';
import '../../widgets/common.dart';

/// Manual scheduling with approval-gated changes: the account holder edits
/// directly; caregivers propose, and the change only takes effect after the
/// account holder approves it.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = 180;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      setState(() =>
          _minutes = app.bundle?.household.schedule.intervalMinutes ?? 180);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final schedule = app.bundle?.household.schedule;
    final isHolder = app.isAccountHolder;
    final pending = schedule?.pendingChange;
    final dirty = _minutes != (schedule?.intervalMinutes ?? 180);
    final label = FeedingSchedule(intervalMinutes: _minutes).intervalLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Feeding schedule')),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          VoxelCard(
            child: Column(
              children: [
                Text('FEED INTERVAL', style: LivyType.label()),
                const SizedBox(height: LivySpace.sm),
                Text(label,
                    style: LivyType.data(
                        size: 40, weight: FontWeight.w700, color: LivyColors.amber)),
                Slider(
                  value: _minutes.toDouble(),
                  min: 90,
                  max: 360,
                  divisions: (360 - 90) ~/ 15,
                  activeColor: LivyColors.amber,
                  inactiveColor: LivyColors.surfaceSunken,
                  onChanged: (v) {
                    if (v.round() != _minutes) Haptics.tap();
                    setState(() => _minutes = (v / 15).round() * 15);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('every 1h 30m', style: LivyType.body(size: 12, color: LivyColors.faint)),
                    Text('every 6h', style: LivyType.body(size: 12, color: LivyColors.faint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: LivySpace.md),
          if (isHolder)
            VoxelButton(
              label: dirty ? 'Set schedule to $label' : 'Schedule is up to date',
              icon: Icons.check_rounded,
              onPressed: dirty
                  ? () async {
                      await app.setScheduleInterval(_minutes);
                      if (context.mounted) Navigator.of(context).maybePop();
                    }
                  : null,
            )
          else
            VoxelButton(
              label: dirty ? 'Propose $label' : 'No change to propose',
              icon: Icons.outgoing_mail,
              onPressed: dirty && pending == null
                  ? () async {
                      await app.proposeScheduleChange(_minutes);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content:
                                Text('Sent to the account holder for approval')));
                      }
                    }
                  : null,
            ),
          if (!isHolder)
            Padding(
              padding: const EdgeInsets.only(top: LivySpace.sm),
              child: Text(
                'Schedule changes take effect once the account holder approves them.',
                textAlign: TextAlign.center,
                style: LivyType.body(size: 12, color: LivyColors.faint),
              ),
            ),
          if (pending != null && pending.state == ScheduleChangeState.pending) ...[
            const SectionHeader('Pending proposal'),
            VoxelCard(
              color: LivyColors.periwinkle.withValues(alpha: 0.08),
              borderColor: LivyColors.periwinkle.withValues(alpha: 0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${pending.proposedByName} proposed '
                    '${FeedingSchedule(intervalMinutes: pending.proposedIntervalMinutes).intervalLabel}',
                    style: LivyType.body(size: 15, weight: FontWeight.w700),
                  ),
                  if (app.isAccountHolder) ...[
                    const SizedBox(height: LivySpace.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => app.resolveScheduleChange(approve: false),
                          child: Text('Decline',
                              style: LivyType.body(size: 14, color: LivyColors.mist)),
                        ),
                        TextButton(
                          onPressed: () => app.resolveScheduleChange(approve: true),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SectionHeader('How Livy uses this'),
          VoxelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The nightlight dial fills across this interval, reminders fire when a feed '
                  'comes due, and "on time" streaks count feeds landing within ±25 minutes of '
                  'it. As your baby grows and stretches their rhythm, Livy will gently point '
                  'out when the real pattern drifts away from this setting.',
                  style: LivyType.body(size: 14, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.sm),
                Text(
                  'You choose this interval — Livy never sets it for you. General '
                  'guidance on how feeding amounts and intervals change with age:',
                  style: LivyType.body(size: 12, color: LivyColors.faint),
                ),
                const SizedBox(height: LivySpace.xs),
                const InlineCitations(HealthSources.bottleFeeding),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
