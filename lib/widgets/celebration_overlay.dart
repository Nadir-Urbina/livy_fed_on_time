import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../models/badge_catalog.dart';
import '../models/mascots.dart';
import '../services/haptics.dart';
import '../services/sound_service.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'mascot_view.dart';

/// Full-screen celebratory moment: confetti, the generated badge art dropping
/// in with a spring, Livy delighted, haptic + synthesized chime. Calm colors,
/// no harsh flashing — quiet-hours appropriate.
Future<void> showBadgeCelebration(
  BuildContext context, {
  required BadgeDef badge,
  required MascotDef mascot,
  required String mascotName,
}) {
  Haptics.celebrate();
  SoundService.instance.celebration();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'badge',
    barrierColor: LivyColors.scrim,
    transitionDuration: LivyMotion.medium,
    pageBuilder: (context, _, _) => _BadgeCelebration(
      badge: badge,
      mascot: mascot,
      mascotName: mascotName,
    ),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _BadgeCelebration extends StatefulWidget {
  const _BadgeCelebration({
    required this.badge,
    required this.mascot,
    required this.mascotName,
  });

  final BadgeDef badge;
  final MascotDef mascot;
  final String mascotName;

  @override
  State<_BadgeCelebration> createState() => _BadgeCelebrationState();
}

class _BadgeCelebrationState extends State<_BadgeCelebration> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: Duration(seconds: 2))..play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.02,
              numberOfParticles: 18,
              gravity: 0.12,
              maxBlastForce: 22,
              minBlastForce: 8,
              colors: [
                LivyColors.amber,
                LivyColors.coral,
                LivyColors.butter,
                LivyColors.mint,
                LivyColors.periwinkle,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(LivySpace.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: LivyMotion.slow,
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(LivyRadius.lg),
                    child: Image.asset(
                      widget.badge.asset,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: LivyColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(LivyRadius.lg),
                        ),
                        child: Icon(Icons.emoji_events_rounded,
                            size: 80, color: LivyColors.amber),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: LivySpace.lg),
                Text('Badge unlocked', style: LivyType.label(color: LivyColors.butter)),
                const SizedBox(height: LivySpace.xs),
                Text(widget.badge.title,
                    textAlign: TextAlign.center, style: LivyType.display(size: 30)),
                const SizedBox(height: LivySpace.md),
                Text(
                  '"${widget.badge.flavor}"',
                  textAlign: TextAlign.center,
                  style: LivyType.body(size: 15, color: LivyColors.mist),
                ),
                Text('— ${widget.mascotName}',
                    style: LivyType.body(size: 13, color: LivyColors.faint)),
                const SizedBox(height: LivySpace.lg),
                MascotReaction(mascot: widget.mascot, pose: MascotPose.delighted, size: 130),
                const SizedBox(height: LivySpace.xl),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Lovely'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight confetti burst pinned to the top of a screen (used on on-time
/// logs and tag-team moments, without the full takeover).
class MiniConfetti extends StatefulWidget {
  const MiniConfetti({super.key, required this.trigger});

  /// Increment to fire a burst.
  final int trigger;

  @override
  State<MiniConfetti> createState() => _MiniConfettiState();
}

class _MiniConfettiState extends State<MiniConfetti> {
  late final ConfettiController _c;

  @override
  void initState() {
    super.initState();
    _c = ConfettiController(duration: Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(covariant MiniConfetti old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _c.play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _c,
          blastDirection: pi / 2,
          emissionFrequency: 0.05,
          numberOfParticles: 10,
          gravity: 0.15,
          maxBlastForce: 15,
          minBlastForce: 5,
          colors: [LivyColors.amber, LivyColors.coral, LivyColors.mint],
        ),
      ),
    );
  }
}
