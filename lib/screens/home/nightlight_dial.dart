import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../../theme/tokens.dart';

/// The centerpiece: a nightlight ring that fills as time passes since the
/// last feed. Cool restful periwinkle right after a feed, warming through
/// amber as the next feed approaches, soft coral when due — and the whole
/// ring "breathes" like a sleeping nightlight. Rendered with CustomPainter;
/// progress changes animate smoothly.
class NightlightDial extends StatefulWidget {
  const NightlightDial({
    super.key,
    required this.progress,
    required this.centerTop,
    required this.centerBig,
    required this.centerBottom,
    this.overdue = false,
    this.size = 300,
  });

  /// 0.0 (just fed) → 1.0 (feed due).
  final double progress;
  final String centerTop;
  final String centerBig;
  final String centerBottom;
  final bool overdue;
  final double size;

  @override
  State<NightlightDial> createState() => _NightlightDialState();
}

class _NightlightDialState extends State<NightlightDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.progress.clamp(0.0, 1.0)),
      duration: LivyMotion.slow,
      curve: LivyMotion.settle,
      builder: (context, progress, _) => AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) {
          final breathe = Curves.easeInOut.transform(_breathe.value);
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(widget.size),
                  painter: _DialPainter(
                    progress: progress,
                    breathe: breathe,
                    overdue: widget.overdue,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.centerTop, style: LivyType.label(size: 11)),
                    const SizedBox(height: 6),
                    Text(
                      widget.centerBig,
                      style: LivyType.data(
                        size: widget.size * 0.155,
                        weight: FontWeight.w700,
                        color: widget.overdue ? LivyColors.rose : LivyColors.cream,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(widget.centerBottom,
                        style: LivyType.body(size: 13, color: LivyColors.mist)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress, required this.breathe, required this.overdue});

  final double progress;
  final double breathe;
  final bool overdue;

  static const _startAngle = -math.pi / 2; // 12 o'clock
  static const _stroke = 22.0;

  Color get _tipColor {
    if (overdue) return LivyColors.dialEnd;
    if (progress < 0.5) {
      return Color.lerp(LivyColors.dialStart, LivyColors.dialMid, progress * 2)!;
    }
    return Color.lerp(LivyColors.dialMid, LivyColors.dialEnd, (progress - 0.5) * 2)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Sunken track with faint hour ticks.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = LivyColors.surfaceSunken;
    canvas.drawCircle(center, radius, track);

    final tick = Paint()
      ..color = LivyColors.outline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = _startAngle + i * math.pi / 6;
      final inner = center + Offset(math.cos(a), math.sin(a)) * (radius - _stroke / 2 - 7);
      final outer = center + Offset(math.cos(a), math.sin(a)) * (radius - _stroke / 2 - 2);
      canvas.drawLine(inner, outer, tick);
    }

    if (progress <= 0.004) {
      _drawGlowDot(canvas, center, radius, _startAngle);
      return;
    }

    final sweep = 2 * math.pi * progress;

    // Breathing outer glow behind the arc — the "nightlight" effect.
    final glowStrength = 0.20 + 0.14 * breathe + (overdue ? 0.10 : 0);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke + 14 + 6 * breathe
      ..strokeCap = StrokeCap.round
      ..color = _tipColor.withValues(alpha: glowStrength)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawArc(rect, _startAngle, sweep, false, glow);

    // Main gradient arc.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(
        center,
        [
          LivyColors.dialStart,
          LivyColors.dialMid,
          LivyColors.dialEnd,
          LivyColors.dialStart, // wrap smoothing (unused visually below 1.0)
        ],
        [0.0, 0.5, 0.98, 1.0],
        TileMode.clamp,
        0,
        2 * math.pi,
        _rotation(center),
      );
    canvas.drawArc(rect, _startAngle, sweep, false, arc);

    // Bright tip dot marking "now".
    final tipAngle = _startAngle + sweep;
    _drawGlowDot(canvas, center, radius, tipAngle);
  }

  Float64List _rotation(Offset center) {
    // Rotate the sweep gradient so 0 sits at 12 o'clock.
    final m = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..rotateZ(_startAngle)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    return m.storage;
  }

  void _drawGlowDot(Canvas canvas, Offset center, double radius, double angle) {
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      pos,
      9 + 2 * breathe,
      Paint()
        ..color = _tipColor.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(pos, 6, Paint()..color = LivyColors.cream);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.breathe != breathe || old.overdue != overdue;
}
