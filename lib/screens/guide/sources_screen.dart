import 'package:flutter/material.dart';

import '../../data/health_sources.dart';
import '../../legal_links.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/citations.dart';
import '../../widgets/common.dart';

/// Every source behind the general health information Livy shows, grouped by
/// topic and linked to the primary document.
///
/// Reachable from the Care hub, from Settings, from the disclaimer footer that
/// sits under every guidance surface, and from the solids dialog that quotes
/// these sources by name.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sources & references')),
      body: ListView(
        padding: const EdgeInsets.all(LivySpace.lg),
        children: [
          VoxelCard(
            color: LivyColors.surfaceSunken,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livy is a feeding notebook, not a clinician. Most of what she '
                  'shows is your household\'s own logged data. Where she does '
                  'repeat general guidance — the usual age for first foods, how '
                  'bottle amounts and intervals tend to change, formula recalls '
                  '— it comes from the public health sources listed below.',
                  style: LivyType.body(size: 14, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.sm),
                Text(
                  'Tap any source to open the original document. None of it is '
                  'advice about your baby specifically — your pediatrician is '
                  'the one who can give you that.',
                  style: LivyType.body(size: 13, color: LivyColors.faint),
                ),
              ],
            ),
          ),
          for (final group in HealthSources.groups) ...[
            SectionHeader(group.topic),
            Padding(
              padding: const EdgeInsets.only(bottom: LivySpace.sm),
              child: Text(group.blurb,
                  style: LivyType.body(size: 13, color: LivyColors.mist)),
            ),
            for (final c in group.citations) CitationCard(citation: c),
          ],
          const SectionHeader('If you\'re worried right now'),
          VoxelCard(
            borderColor: LivyColors.coral.withValues(alpha: 0.4),
            color: LivyColors.coral.withValues(alpha: 0.06),
            child: Text(
              'Contact your pediatrician, or your local emergency services. '
              'Livy can\'t assess your baby and shouldn\'t be part of an urgent '
              'decision.',
              style: LivyType.body(size: 14, color: LivyColors.mist),
            ),
          ),
          const SectionHeader('App policies'),
          VoxelCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined,
                      color: LivyColors.mist, size: 20),
                  title: Text('Privacy Policy',
                      style: LivyType.body(size: 15)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 16, color: LivyColors.faint),
                  onTap: () => LegalLinks.open(LegalLinks.privacyPolicy),
                ),
                Divider(height: 1, color: LivyColors.outline),
                ListTile(
                  leading: Icon(Icons.description_outlined,
                      color: LivyColors.mist, size: 20),
                  title: Text('Terms of Use', style: LivyType.body(size: 15)),
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: 16, color: LivyColors.faint),
                  onTap: () => LegalLinks.open(LegalLinks.termsOfUse),
                ),
              ],
            ),
          ),
          const SizedBox(height: LivySpace.xxl),
        ],
      ),
    );
  }
}
