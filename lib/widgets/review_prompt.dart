import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/mascots.dart';
import '../services/haptics.dart';
import '../services/review_prompt_service.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'mascot_view.dart';

/// The two-step "how's it going?" ask.
///
/// Step one is a plain question with two equally-weighted answers. A happy
/// answer hands off to Apple's own rating sheet; an unhappy one opens a box to
/// write in. Neither path is nudged: the buttons are the same size, in the
/// same order every time, and "Not now" is always there.
///
/// Deliberately *not* a star picker. Apple asks that the system rating UI not
/// be imitated, so nothing here shows stars or the word "rate" before the
/// system sheet has been handed control.
Future<void> showReviewPrompt(BuildContext context) async {
  final app = context.read<AppState>();
  final service = ReviewPromptService.instance;
  await service.recordAsked(feedCount: app.lifetimeFeedCount);

  if (!context.mounted) return;
  final loving = await showDialog<bool>(
    context: context,
    builder: (ctx) => _SentimentDialog(mascotName: app.mascotName),
  );

  if (loving == null) return; // dismissed — ask again another day
  if (!context.mounted) return;

  if (loving) {
    // They're happy. The question is answered either way, whether or not iOS
    // decides to actually surface its sheet.
    await service.settle();
    await service.openSystemReviewSheet();
    return;
  }

  await _showFeedbackSheet(context);
}

class _SentimentDialog extends StatelessWidget {
  const _SentimentDialog({required this.mascotName});

  final String mascotName;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AlertDialog(
      backgroundColor: LivyColors.surfaceRaised,
      title: Column(
        children: [
          MascotView(
              mascot: app.mascot,
              pose: MascotPose.thoughtful,
              size: 96,
              glow: false),
          const SizedBox(height: LivySpace.sm),
          Text('How\'s $mascotName working out?',
              textAlign: TextAlign.center, style: LivyType.display(size: 20)),
        ],
      ),
      content: Text(
        'You\'ve logged a lot of feeds together. Worth asking how it\'s going.',
        textAlign: TextAlign.center,
        style: LivyType.body(size: 14, color: LivyColors.mist),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(
              child: _FaceButton(
                emoji: '🙂',
                label: 'Loving it',
                accent: LivyColors.butter,
                onTap: () {
                  Haptics.logFeed();
                  Navigator.of(context).pop(true);
                },
              ),
            ),
            const SizedBox(width: LivySpace.sm),
            Expanded(
              child: _FaceButton(
                emoji: '😐',
                label: 'Could be better',
                accent: LivyColors.periwinkle,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Not now',
              style: LivyType.body(size: 13, color: LivyColors.faint)),
        ),
      ],
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.emoji,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LivyRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: LivySpace.md, horizontal: LivySpace.sm),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(LivyRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: LivySpace.xs),
            Text(label,
                textAlign: TextAlign.center,
                style: LivyType.body(
                    size: 13, color: accent, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Where an unhappy answer goes. One box, one button, no triage questions —
/// the point is to hear them, not to make them fill in a form.
Future<void> _showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LivyColors.surfaceRaised,
    builder: (_) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);

    final app = context.read<AppState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    await app.submitFeedback(message);
    // They told us what's wrong. Asking again later would be asking them to
    // repeat themselves.
    await ReviewPromptService.instance.settle();

    navigator.pop();
    messenger?.showSnackBar(SnackBar(
      content: Text('Thank you — that goes straight to the people building Livy.',
          style: LivyType.body(size: 14)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: LivySpace.lg,
        right: LivySpace.lg,
        top: LivySpace.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + LivySpace.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What would make it better?',
              style: LivyType.display(size: 20)),
          const SizedBox(height: LivySpace.xs),
          Text(
            'Tell us what\'s getting in the way. A real person reads these.',
            style: LivyType.body(size: 13, color: LivyColors.mist),
          ),
          const SizedBox(height: LivySpace.md),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: LivyType.body(size: 15),
            decoration: const InputDecoration(
              hintText: 'The thing that bugs me is…',
            ),
          ),
          const SizedBox(height: LivySpace.md),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Sending…' : 'Send feedback'),
          ),
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text('Not right now',
                style: LivyType.body(size: 13, color: LivyColors.faint)),
          ),
        ],
      ),
    );
  }
}
