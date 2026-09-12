import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../models/mascots.dart';
import '../../models/models.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot_view.dart';
import 'sources_screen.dart';

/// Symptom log → pediatrician conversation guide. Compiles the caregiver's own
/// recent entries into a clean, shareable summary with talking-point prompts.
/// It never diagnoses, names a condition, or suggests a treatment — it only
/// organizes the parent's own data and prompts a conversation with a real
/// clinician. A DisclaimerAcknowledgment is logged on first view.
class PediatricianGuideScreen extends StatefulWidget {
  const PediatricianGuideScreen({super.key});

  @override
  State<PediatricianGuideScreen> createState() => _PediatricianGuideScreenState();
}

class _PediatricianGuideScreenState extends State<PediatricianGuideScreen> {
  bool _gateAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      _gateAccepted = app.hasAcknowledgedDisclaimer;
      if (!_gateAccepted) _showGate();
      setState(() {});
    });
  }

  Future<void> _showGate() async {
    final app = context.read<AppState>();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LivyColors.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LivyRadius.lg)),
        title: Text('Before we begin', style: LivyType.display(size: 22)),
        content: Text(
          'This guide organizes your own notes to help you talk with your pediatrician. '
          'It is not medical advice, it cannot diagnose anything, and it never replaces '
          'a clinician. If you\'re worried about your baby right now, contact your '
          'pediatrician or local emergency services.',
          style: LivyType.body(size: 14, color: LivyColors.mist),
        ),
        actions: [
          TextButton(
            onPressed: () => SourcesScreen.open(dialogContext),
            child: Text('Sources',
                style: LivyType.body(color: LivyColors.periwinkle)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Go back', style: LivyType.body(color: LivyColors.mist)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted == true) {
      // Timestamped acknowledgment, recorded once per caregiver.
      await app.acknowledgeDisclaimer();
      setState(() => _gateAccepted = true);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  List<Feed> get _symptomFeeds {
    final feeds = context.read<AppState>().bundle?.feeds ?? const <Feed>[];
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    return feeds
        .where((f) => f.symptoms.isNotEmpty && f.time.isAfter(cutoff))
        .toList();
  }

  Map<SymptomKind, int> get _tally {
    final map = <SymptomKind, int>{};
    for (final f in _symptomFeeds) {
      for (final s in f.symptoms) {
        map[s.kind] = (map[s.kind] ?? 0) + 1;
      }
    }
    return map;
  }

  String _buildShareText(AppState app) {
    final baby = app.bundle!.household.baby;
    final buf = StringBuffer()
      ..writeln('Pediatrician visit notes — ${baby.name} (${baby.ageLabel})')
      ..writeln('Prepared with Livy — Fed On Time on '
          '${DateFormat('MMM d, yyyy').format(DateTime.now())}')
      ..writeln('')
      ..writeln('Recent symptom notes (last 14 days):');
    for (final f in _symptomFeeds) {
      for (final s in f.symptoms) {
        buf.writeln('• ${DateFormat('MMM d, h:mm a').format(f.time)} — '
            '${s.kind.label}${s.note.isNotEmpty ? ' (${s.note})' : ''} '
            '· feed ${app.formatAmount(f.amountMl)}');
      }
    }
    buf
      ..writeln('')
      ..writeln('Questions we may want to ask:');
    for (final q in _talkingPoints()) {
      buf.writeln('• $q');
    }
    buf
      ..writeln('')
      ..writeln('This summary only organizes our own notes — it is not medical advice.');
    return buf.toString();
  }

  /// Neutral, non-diagnostic prompts derived from which kinds of notes exist.
  List<String> _talkingPoints() {
    final tally = _tally;
    final points = <String>[];
    if (tally.containsKey(SymptomKind.gas) || tally.containsKey(SymptomKind.fussiness)) {
      points.add('You may want to ask your pediatrician about the gas/fussiness notes — '
          'whether the pattern we logged is within the normal range.');
    }
    if (tally.containsKey(SymptomKind.spitUp) || tally.containsKey(SymptomKind.reflux)) {
      points.add('You may want to show the spit-up/reflux entries and ask whether the '
          'frequency we recorded is worth watching.');
    }
    if (tally.containsKey(SymptomKind.poop)) {
      points.add('You may want to mention the diaper notes and ask what changes, if any, '
          'would be worth a call.');
    }
    points.add('Are the feed amounts and intervals in our log about what you\'d expect '
        'at this age?');
    points.add('Is there anything in this log you\'d like us to track differently?');
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feeds = _symptomFeeds;
    final tally = _tally;

    return Scaffold(
      appBar: AppBar(title: const Text('Pediatrician visit guide')),
      body: !_gateAccepted
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(LivySpace.lg),
              children: [
                Row(
                  children: [
                    MascotView(mascot: app.mascot, pose: MascotPose.thoughtful, size: 72, glow: false),
                    const SizedBox(width: LivySpace.md),
                    Expanded(
                      child: Text(
                        feeds.isEmpty
                            ? 'No symptom notes in the last two weeks. When you add them '
                                'to a feed, ${app.mascotName} will gather them here.'
                            : '${app.mascotName} gathered your notes from the last two '
                                'weeks into one tidy summary for the visit.',
                        style: LivyType.body(size: 14, color: LivyColors.mist),
                      ),
                    ),
                  ],
                ),
                if (feeds.isNotEmpty) ...[
                  const SectionHeader('At a glance'),
                  Wrap(
                    spacing: LivySpace.sm,
                    runSpacing: LivySpace.sm,
                    children: tally.entries
                        .map((e) => Chip(
                              label: Text('${e.key.label} ×${e.value}'),
                              backgroundColor: LivyColors.coral.withValues(alpha: 0.12),
                              labelStyle: LivyType.body(size: 13, color: LivyColors.coral),
                              side: BorderSide(
                                  color: LivyColors.coral.withValues(alpha: 0.35)),
                            ))
                        .toList(),
                  ),
                  const SectionHeader('Logged entries'),
                  for (final f in feeds)
                    Padding(
                      padding: const EdgeInsets.only(bottom: LivySpace.sm),
                      child: VoxelCard(
                        padding: const EdgeInsets.all(LivySpace.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('EEE, MMM d · h:mm a').format(f.time),
                                style: LivyType.data(size: 13, color: LivyColors.mist)),
                            const SizedBox(height: 4),
                            for (final s in f.symptoms)
                              Text(
                                  '${s.kind.label}${s.note.isNotEmpty ? ' — ${s.note}' : ''}',
                                  style: LivyType.body(size: 14)),
                            Text(
                                'Feed: ${app.formatAmount(f.amountMl)}'
                                '${f.formulaBrand != null ? ' · ${f.formulaBrand}' : ''}',
                                style: LivyType.body(size: 12, color: LivyColors.faint)),
                          ],
                        ),
                      ),
                    ),
                  const SectionHeader('You may want to ask…'),
                  VoxelCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final q in _talkingPoints())
                          Padding(
                            padding: const EdgeInsets.only(bottom: LivySpace.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 16, color: LivyColors.mint),
                                const SizedBox(width: LivySpace.sm),
                                Expanded(child: Text(q, style: LivyType.body(size: 14))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LivySpace.lg),
                  VoxelButton(
                    label: 'Share / print summary',
                    icon: Icons.ios_share_rounded,
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: _buildShareText(app))),
                  ),
                ],
                const DisclaimerFooter(),
              ],
            ),
    );
  }
}
