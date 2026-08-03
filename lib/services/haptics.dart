import 'package:flutter/services.dart';

/// Semantic haptic vocabulary — one call site per meaning, so the physical
/// language stays consistent app-wide.
abstract final class Haptics {
  static void tap() => HapticFeedback.selectionClick();
  static void logFeed() => HapticFeedback.mediumImpact();
  static void celebrate() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  static void warn() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.lightImpact();
}
