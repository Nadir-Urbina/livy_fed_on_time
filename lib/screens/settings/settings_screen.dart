import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../legal_links.dart';
import '../../models/mascots.dart';
import '../../services/haptics.dart';
import '../../services/notification_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sound_service.dart';
import '../../theme/theme.dart';
import '../../theme/theme_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';

/// Mascot picker (rename or reskin Livy — the granny is always available),
/// units, sounds, notifications, and demo utilities.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mascot & settings')),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          Center(
            child: Column(
              children: [
                MascotView(mascot: app.mascot, size: 160),
                const SizedBox(height: LivySpace.sm),
                Text(app.mascotName, style: LivyType.display(size: 24)),
                Text(app.mascot.tagline,
                    textAlign: TextAlign.center,
                    style: LivyType.body(size: 13, color: LivyColors.mist)),
                TextButton.icon(
                  onPressed: () => _rename(context, app),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text('Rename ${app.mascotName}'),
                ),
              ],
            ),
          ),
          const SectionHeader('Choose your companion'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: LivySpace.sm,
            crossAxisSpacing: LivySpace.sm,
            childAspectRatio: 0.82,
            children: [
              for (final m in MascotCatalog.all)
                _MascotChoice(
                  def: m,
                  selected: m.id == app.mascot.id,
                  onTap: () {
                    Haptics.success();
                    SoundService.instance.feedLogged();
                    // Custom names are per-mascot; switching resets to the
                    // mascot's own default name.
                    app.setMascot(mascotId: m.id);
                  },
                ),
            ],
          ),
          const SectionHeader('Theme'),
          VoxelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livy opens in the nightlight. Switch to Auto to follow the '
                  'sun — sunny by day, golden at dusk — or pin any look you '
                  'prefer.',
                  style: LivyType.body(size: 13, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.md),
                Consumer<ThemeController>(
                  builder: (context, themes, _) => Wrap(
                    spacing: LivySpace.sm,
                    children: [
                      for (final o in ThemeOverride.values)
                        ChoiceChip(
                          label: Text(switch (o) {
                            ThemeOverride.auto => 'Auto',
                            ThemeOverride.day => 'Day',
                            ThemeOverride.dusk => 'Dusk',
                            ThemeOverride.night => 'Night',
                          }),
                          avatar: Icon(
                            switch (o) {
                              ThemeOverride.auto => Icons.brightness_auto_rounded,
                              ThemeOverride.day => Icons.wb_sunny_rounded,
                              ThemeOverride.dusk => Icons.wb_twilight_rounded,
                              ThemeOverride.night => Icons.nightlight_round,
                            },
                            size: 16,
                            color: themes.overrideMode == o
                                ? LivyColors.amberDeep
                                : LivyColors.faint,
                          ),
                          selected: themes.overrideMode == o,
                          onSelected: (_) {
                            Haptics.tap();
                            themes.setOverride(o);
                          },
                          selectedColor: LivyColors.amber.withValues(alpha: 0.22),
                          backgroundColor: LivyColors.surfaceSunken,
                          labelStyle: LivyType.body(
                              size: 13,
                              color: themes.overrideMode == o
                                  ? LivyColors.cream
                                  : LivyColors.mist),
                          side: BorderSide(color: LivyColors.outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Preferences'),
          VoxelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Use milliliters (mL)', style: LivyType.body(size: 15)),
                  subtitle: Text('Off shows ounces (oz)',
                      style: LivyType.body(size: 12, color: LivyColors.mist)),
                  value: app.useMetric,
                  onChanged: (_) => app.toggleUnits(),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text('Gentle sounds', style: LivyType.body(size: 15)),
                  subtitle: Text('Soft synthesized chimes on key moments',
                      style: LivyType.body(size: 12, color: LivyColors.mist)),
                  value: SoundService.instance.enabled,
                  onChanged: (v) =>
                      setState(() => SoundService.instance.enabled = v),
                ),
                const Divider(),
                ListTile(
                  title: Text('Feed reminders', style: LivyType.body(size: 15)),
                  subtitle: Text(
                      'A time-sensitive nudge when the next feed comes due',
                      style: LivyType.body(size: 12, color: LivyColors.mist)),
                  trailing: TextButton(
                    onPressed: () async {
                      final granted =
                          await NotificationService.instance.requestPermission();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(granted
                                ? 'Reminders enabled'
                                : 'Enable notifications in iOS Settings')));
                      }
                    },
                    child: const Text('Enable'),
                  ),
                ),
              ],
            ),
          ),
          if (!app.isDemo) ...[
            const SectionHeader('Account'),
            VoxelCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading:
                        Icon(Icons.person_outline_rounded, color: LivyColors.mist),
                    title: Text('Signed in', style: LivyType.body(size: 15)),
                    subtitle: Text(
                      FirebaseAuth.instance.currentUser?.email ??
                          app.caregiverName,
                      style: LivyType.body(size: 12, color: LivyColors.mist),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: LivyColors.mist),
                    title: Text('Sign out', style: LivyType.body(size: 15)),
                    onTap: () => _signOut(context, app),
                  ),
                  const Divider(),
                  ListTile(
                    leading:
                        Icon(Icons.delete_forever_rounded, color: LivyColors.rose),
                    title: Text('Delete account…',
                        style: LivyType.body(size: 15, color: LivyColors.rose)),
                    subtitle: Text(
                      'Permanently removes your account and data',
                      style: LivyType.body(size: 12, color: LivyColors.mist),
                    ),
                    onTap: () => _deleteAccount(context, app),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader('About'),
          VoxelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: LivyColors.mist),
                  title: Text('Privacy Policy', style: LivyType.body(size: 15)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 16, color: LivyColors.faint),
                  onTap: () => LegalLinks.open(LegalLinks.privacyPolicy),
                ),
                const Divider(),
                ListTile(
                  leading:
                      Icon(Icons.description_outlined, color: LivyColors.mist),
                  title: Text('Terms of Use', style: LivyType.body(size: 15)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 16, color: LivyColors.faint),
                  onTap: () => LegalLinks.open(LegalLinks.termsOfUse),
                ),
              ],
            ),
          ),
          if (app.isDemo) ...[
            const SectionHeader('Demo'),
            VoxelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You\'re in demo mode — no Firebase project configured. All data is '
                    'local sample data; connect Firebase (see README) for real household '
                    'sync.',
                    style: LivyType.body(size: 13, color: LivyColors.mist),
                  ),
                  const SizedBox(height: LivySpace.sm),
                  TextButton.icon(
                    onPressed: () async {
                      await app.resetDemo();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset demo data'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await app.replayOnboarding();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Try onboarding & paywall from scratch'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, AppState app) async {
    // Captured up front: the context is popped before these are needed.
    final purchases = context.read<PurchaseService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Sign out?', style: LivyType.display(size: 20)),
        content: Text(
          'Your household stays safely in the cloud — sign back in anytime.',
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await app.signOutAndReset();
    await purchases.forgetUser();
  }

  Future<void> _deleteAccount(BuildContext context, AppState app) async {
    final holder = app.isAccountHolder;
    final baby = app.bundle?.household.baby.name ?? 'your baby';
    final messenger = ScaffoldMessenger.of(context);
    final purchases = context.read<PurchaseService>();

    // Step 1: spell out exactly what disappears (role-aware).
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Delete your account?', style: LivyType.display(size: 20)),
        content: Text(
          holder
              ? 'You are the account holder, so this deletes the ENTIRE '
                  'household: every feed ever logged for $baby, streaks, '
                  'badges, and journals — for every caregiver. This cannot '
                  'be undone.\n\nManage or cancel your subscription '
                  'separately in iOS Settings → Apple Account → Subscriptions.'
              : 'This removes your caregiver seat and deletes your account. '
                  'The household and its history remain with the other '
                  'caregivers. This cannot be undone.',
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Continue',
                style: LivyType.body(
                    size: 15, weight: FontWeight.w700, color: LivyColors.rose)),
          ),
        ],
      ),
    );
    if (ok1 != true || !context.mounted) return;

    // Step 2: final, unambiguous confirmation.
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Last check', style: LivyType.display(size: 20)),
        content: Text(
          holder
              ? 'Permanently delete the household and your account?'
              : 'Permanently delete your account?',
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep my account')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete forever',
                style: LivyType.body(
                    size: 15, weight: FontWeight.w700, color: LivyColors.rose)),
          ),
        ],
      ),
    );
    if (ok2 != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteAccount').call();
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      await app.signOutAndReset();
      await purchases.forgetUser();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // progress dialog
      messenger.showSnackBar(SnackBar(
          content: Text('Couldn\'t delete the account: $e')));
    }
  }

  Future<void> _rename(BuildContext context, AppState app) async {
    final controller = TextEditingController(text: app.mascotName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        title: Text('Name your companion', style: LivyType.display(size: 20)),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: LivyType.body(color: LivyColors.mist))),
          TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await app.setMascot(mascotId: app.mascot.id, customName: name);
    }
  }
}

class _MascotChoice extends StatelessWidget {
  const _MascotChoice({required this.def, required this.selected, required this.onTap});

  final MascotDef def;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VoxelCard(
      padding: const EdgeInsets.all(LivySpace.sm),
      borderColor: selected ? LivyColors.amber : LivyColors.outline,
      color: selected ? LivyColors.amber.withValues(alpha: 0.07) : LivyColors.surface,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(LivyRadius.sm),
              child: Image.asset(
                MascotAssetResolver.instance.resolvePose(def, MascotPose.idle),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: LivyColors.surfaceSunken,
                  child: Icon(Icons.auto_awesome,
                      color: LivyColors.amber, size: 40),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(def.defaultName,
              style: LivyType.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: selected ? LivyColors.amber : LivyColors.cream)),
          if (selected) Text('ACTIVE', style: LivyType.label(size: 8, color: LivyColors.amber)),
        ],
      ),
    );
  }
}
