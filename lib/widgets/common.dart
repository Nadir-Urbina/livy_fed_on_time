import 'package:flutter/material.dart';

import '../screens/guide/sources_screen.dart';
import '../services/haptics.dart';
import '../services/sound_service.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Standard Livy card.
class VoxelCard extends StatelessWidget {
  const VoxelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LivySpace.md),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? LivyColors.surface,
        borderRadius: BorderRadius.circular(LivyRadius.md),
        border: Border.all(color: borderColor ?? LivyColors.outline),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(LivyRadius.md),
        onTap: () {
          Haptics.tap();
          SoundService.instance.tick();
          onTap!();
        },
        child: card,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LivySpace.sm, top: LivySpace.lg),
      child: Row(
        children: [
          Expanded(child: Text(title, style: LivyType.display(size: 20))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small labeled stat with an animated rolling number.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.accent, this.suffix = ''});

  final String label;
  final num value;
  final Color? accent;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return VoxelCard(
      padding: const EdgeInsets.symmetric(vertical: LivySpace.md, horizontal: LivySpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumberRollup(value: value, style: LivyType.data(size: 26, color: accent ?? LivyColors.amber, weight: FontWeight.w700), suffix: suffix),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: LivyType.label(size: 10)),
        ],
      ),
    );
  }
}

/// Animated count-up used for stats and celebration numbers.
class NumberRollup extends StatelessWidget {
  const NumberRollup({super.key, required this.value, required this.style, this.suffix = '', this.decimals = 0});

  final num value;
  final TextStyle style;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: LivyMotion.slow,
      curve: LivyMotion.settle,
      builder: (context, v, _) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// The persistent medical framing required anywhere guide/recommendation
/// content appears, plus the link to the sources behind that information.
/// Never remove either half.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: LivySpace.md),
      padding: const EdgeInsets.all(LivySpace.md),
      decoration: BoxDecoration(
        color: LivyColors.surfaceSunken,
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        border: Border.all(color: LivyColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, size: 16, color: LivyColors.coral),
          const SizedBox(width: LivySpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livy organizes your own notes and shares general information only — she never '
                  'diagnoses, prescribes, or replaces medical care. Always talk with your '
                  'pediatrician about your baby\'s health.',
                  style: LivyType.body(size: 12, color: LivyColors.mist),
                ),
                const SizedBox(height: LivySpace.xs),
                // Guideline 1.4.1: wherever the disclaimer appears, the
                // citations behind the general information are one tap away.
                InkWell(
                  borderRadius: BorderRadius.circular(LivyRadius.sm),
                  onTap: () => SourcesScreen.open(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 14, color: LivyColors.periwinkle),
                        const SizedBox(width: 4),
                        Text(
                          'Sources & references',
                          style: LivyType.body(
                            size: 12,
                            color: LivyColors.periwinkle,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber "recommendation" framing — visually distinct from factual log data.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LivySpace.md),
      decoration: BoxDecoration(
        color: LivyColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(LivyRadius.md),
        border: Border.all(color: LivyColors.amber.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

/// Tag shown wherever demo-mode data is on screen.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: LivyColors.periwinkle.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(LivyRadius.pill),
        border: Border.all(color: LivyColors.periwinkle.withValues(alpha: 0.4)),
      ),
      child: Text('DEMO', style: LivyType.label(size: 9, color: LivyColors.periwinkle)),
    );
  }
}

/// Primary action button with press feedback (scale + haptic + tick).
class VoxelButton extends StatefulWidget {
  const VoxelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.textColor,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool expanded;

  @override
  State<VoxelButton> createState() => _VoxelButtonState();
}

class _VoxelButtonState extends State<VoxelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.color ?? LivyColors.amber;
    final textColor = widget.textColor ?? LivyColors.ink;
    final child = AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: LivyMotion.fast,
      curve: Curves.easeOut,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: LivySpace.lg),
        decoration: BoxDecoration(
          color: enabled ? color : LivyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(LivyRadius.md),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: enabled ? textColor : LivyColors.faint, size: 22),
              const SizedBox(width: LivySpace.sm),
            ],
            Text(
              widget.label,
              style: LivyType.body(
                size: 16,
                weight: FontWeight.w800,
                color: enabled ? textColor : LivyColors.faint,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              Haptics.tap();
              SoundService.instance.tick();
              widget.onPressed!();
            }
          : null,
      child: child,
    );
  }
}
