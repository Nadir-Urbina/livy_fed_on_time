import 'dart:async';

import 'package:flutter/material.dart';

import '../models/mascots.dart';
import '../theme/tokens.dart';

/// Livy on screen. Plays the extracted idle-loop sprite frames when the pose
/// is idle and the active mascot shipped with a loop; swaps to reference-locked
/// pose art (with a soft spring) for reactions. Falls back to a gentle
/// code-driven breathing animation when no sprite loop exists for a mascot.
class MascotView extends StatefulWidget {
  const MascotView({
    super.key,
    required this.mascot,
    this.pose = MascotPose.idle,
    this.size = 180,
    this.glow = true,
  });

  final MascotDef mascot;
  final MascotPose pose;
  final double size;
  final bool glow;

  @override
  State<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends State<MascotView> with SingleTickerProviderStateMixin {
  Timer? _frameTimer;
  int _frame = 0;
  int _frameCount = 0;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _setupLoop();
  }

  @override
  void didUpdateWidget(covariant MascotView old) {
    super.didUpdateWidget(old);
    if (old.mascot.id != widget.mascot.id || old.pose != widget.pose) _setupLoop();
  }

  void _setupLoop() {
    _frameTimer?.cancel();
    _frameCount = widget.pose == MascotPose.idle
        ? MascotAssetResolver.instance.availableIdleFrames(widget.mascot)
        : 0;
    if (_frameCount > 1) {
      // 16 frames over 5s ≈ 312ms per frame, ping-pong for a seamless loop.
      _frameTimer = Timer.periodic(const Duration(milliseconds: 312), (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % (_frameCount * 2 - 2));
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  int get _pingPongFrame =>
      _frame < _frameCount ? _frame : (_frameCount * 2 - 2) - _frame;

  @override
  Widget build(BuildContext context) {
    final resolver = MascotAssetResolver.instance;
    Widget image;
    if (widget.pose == MascotPose.idle && _frameCount > 1) {
      image = Image.asset(
        MascotAssetResolver.instance.idleFrame(widget.mascot, _pingPongFrame),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else {
      final asset = resolver.resolvePose(widget.mascot, widget.pose);
      image = AnimatedScale(
        scale: 1,
        duration: LivyMotion.medium,
        child: Image.asset(
          asset,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
      // Breathing fallback keeps even static poses subtly alive.
      image = AnimatedBuilder(
        animation: _breath,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.015 * _breath.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
        child: image,
      );
    }

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.18),
      child: image,
    );

    if (!widget.glow) return framed;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.18),
        boxShadow: [
          BoxShadow(
            color: LivyColors.amber.withValues(alpha: 0.14),
            blurRadius: widget.size * 0.25,
            spreadRadius: widget.size * 0.02,
          ),
        ],
      ),
      child: framed,
    );
  }

  /// Tasteful vector placeholder — only shown if a generation failed and the
  /// asset is genuinely missing from the bundle.
  Widget _fallback() => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: LivyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(widget.size * 0.18),
          border: Border.all(color: LivyColors.outline),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.auto_awesome, color: LivyColors.amber, size: widget.size * 0.3),
      );
}

/// A one-off pose reaction that pops in and settles back — used when Livy
/// reacts to an event on top of the idle loop.
class MascotReaction extends StatelessWidget {
  const MascotReaction({
    super.key,
    required this.mascot,
    required this.pose,
    this.size = 180,
  });

  final MascotDef mascot;
  final MascotPose pose;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(pose),
      tween: Tween(begin: 0.7, end: 1),
      duration: LivyMotion.medium,
      curve: LivyMotion.spring,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: MascotView(mascot: mascot, pose: pose, size: size),
    );
  }
}
