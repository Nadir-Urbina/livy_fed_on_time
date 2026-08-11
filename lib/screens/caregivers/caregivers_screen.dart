import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../services/haptics.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Multi-caregiver seats: one subscription covers the household; the account
/// holder shares a frictionless invite code/link (up to 5 seats).
class CaregiversScreen extends StatelessWidget {
  const CaregiversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final household = app.bundle?.household;
    if (household == null) return const SizedBox.shrink();
    final seatsLeft = Household.maxCaregivers - household.caregivers.length;
    final code = household.inviteCode ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text('Caregivers')),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          for (final c in household.caregivers)
            Padding(
              padding: const EdgeInsets.only(bottom: LivySpace.sm),
              child: VoxelCard(
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (c.isAccountHolder ? LivyColors.amber : LivyColors.coral)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(LivyRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        c.name.characters.first.toUpperCase(),
                        style: LivyType.data(
                            size: 18,
                            weight: FontWeight.w700,
                            color:
                                c.isAccountHolder ? LivyColors.amber : LivyColors.coral),
                      ),
                    ),
                    const SizedBox(width: LivySpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.name}${c.id == app.caregiverId ? ' (you)' : ''}',
                            style: LivyType.body(size: 15, weight: FontWeight.w700),
                          ),
                          Text(
                            c.isAccountHolder
                                ? 'Account holder'
                                : c.joinedAt != null
                                    ? 'Joined ${DateFormat('MMM d').format(c.joinedAt!)}'
                                    : 'Caregiver',
                            style: LivyType.body(size: 12, color: LivyColors.mist),
                          ),
                        ],
                      ),
                    ),
                    if (app.isAccountHolder && !c.isAccountHolder)
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => _confirmRemove(context, app, c),
                        icon: Icon(Icons.person_remove_outlined,
                            size: 20, color: LivyColors.faint),
                      ),
                  ],
                ),
              ),
            ),
          const SectionHeader('Invite a caregiver'),
          VoxelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seatsLeft > 0
                      ? '$seatsLeft of ${Household.maxCaregivers} seats open — one plan '
                          'covers everyone. Share this code and they\'ll land straight in '
                          '${household.baby.name}\'s household.'
                      : 'All ${Household.maxCaregivers} seats are in use.',
                  style: LivyType.body(size: 14, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.md),
                GestureDetector(
                  onTap: () {
                    Haptics.success();
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')));
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(LivySpace.md),
                    decoration: BoxDecoration(
                      color: LivyColors.surfaceSunken,
                      borderRadius: BorderRadius.circular(LivyRadius.sm),
                      border: Border.all(
                          color: LivyColors.periwinkle.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(code,
                            style: LivyType.data(
                                size: 20,
                                weight: FontWeight.w700,
                                color: LivyColors.periwinkle)),
                        const SizedBox(width: LivySpace.sm),
                        Icon(Icons.copy_rounded,
                            size: 16, color: LivyColors.periwinkle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: LivySpace.md),
                VoxelButton(
                  label: 'Share invite',
                  icon: Icons.ios_share_rounded,
                  onPressed: seatsLeft > 0
                      // The code sits alone on its own line: in Messages a
                      // long-press then selects just the code, instead of
                      // dragging handles through a sentence. No livy:// link —
                      // the scheme isn't registered, so tapping it failed.
                      ? () => SharePlus.instance.share(ShareParams(
                          text:
                              'Join ${household.baby.name}\'s feeding circle on Livy — '
                              'Fed On Time.\n\n'
                              'Invite code:\n'
                              '$code\n\n'
                              'Download Livy, and when setup asks about your baby, tap '
                              '"Have an invite code?" and paste it in. You won\'t need a '
                              'subscription — this household\'s plan covers you.'))
                      : null,
                ),
                if (app.isDemo) ...[
                  const SizedBox(height: LivySpace.sm),
                  TextButton.icon(
                    onPressed: seatsLeft > 0
                        ? () => _addDemoCaregiver(context, app)
                        : null,
                    icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                    label: const Text('Simulate a caregiver joining (demo)'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDemoCaregiver(BuildContext context, AppState app) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Who\'s joining?', style: LivyType.display(size: 20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Grandma Rosa'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: LivyType.body(color: LivyColors.mist))),
          TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Join')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await app.addDemoCaregiver(name);
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, AppState app, Caregiver c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Remove ${c.name}?', style: LivyType.display(size: 20)),
        content: Text(
          'They\'ll lose access to the household. Their past logged feeds stay in the '
          'history.',
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Keep', style: LivyType.body(color: LivyColors.mist))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Remove', style: LivyType.body(color: LivyColors.rose))),
        ],
      ),
    );
    if (confirmed == true) await app.removeCaregiver(c.id);
  }
}
