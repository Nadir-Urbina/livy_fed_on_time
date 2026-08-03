import 'dart:ui' show Brightness;

import 'package:flutter/animation.dart';


/// Livy design tokens — the single source of truth for color, space, type,
/// radius and motion.
///
/// The palette is TIME-ADAPTIVE: a warm sunny palette in the daytime, a
/// golden-hour palette in the late afternoon, and the deep-indigo nightlight
/// palette after dark (still tuned to pass the "comfortable at 3am next to a
/// sleeping baby" test). `LivyColors` keeps its original member names — they
/// are semantic roles (e.g. `cream` = primary text, `night` = scaffold), and
/// resolve against whichever phase palette is active.
enum ThemePhase { day, dusk, night }

ThemePhase phaseForTime(DateTime t) {
  final h = t.hour;
  if (h >= 6 && h < 16) return ThemePhase.day;
  if (h >= 16 && h < 20) return ThemePhase.dusk;
  return ThemePhase.night;
}

class LivyPalette {
  const LivyPalette({
    required this.brightness,
    required this.night,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.outline,
    required this.amber,
    required this.amberDeep,
    required this.coral,
    required this.coralDeep,
    required this.cream,
    required this.mist,
    required this.faint,
    required this.mint,
    required this.butter,
    required this.rose,
    required this.periwinkle,
    required this.dialStart,
    required this.dialMid,
    required this.dialEnd,
    required this.scrim,
    required this.ink,
  });

  final Brightness brightness;
  final Color night;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color outline;
  final Color amber;
  final Color amberDeep;
  final Color coral;
  final Color coralDeep;
  final Color cream;
  final Color mist;
  final Color faint;
  final Color mint;
  final Color butter;
  final Color rose;
  final Color periwinkle;
  final Color dialStart;
  final Color dialMid;
  final Color dialEnd;
  final Color scrim;
  final Color ink;
}

/// After dark: the original deep indigo nightlight.
const nightPalette = LivyPalette(
  brightness: Brightness.dark,
  night: Color(0xFF0E1026),
  surface: Color(0xFF171935),
  surfaceRaised: Color(0xFF1F2244),
  surfaceSunken: Color(0xFF0B0D1F),
  outline: Color(0xFF2C3059),
  amber: Color(0xFFFFB65C),
  amberDeep: Color(0xFFE89A3C),
  coral: Color(0xFFFF8B7A),
  coralDeep: Color(0xFFE9705F),
  cream: Color(0xFFF4EEE1),
  mist: Color(0xFFA3A6C9),
  faint: Color(0xFF6E7194),
  mint: Color(0xFF8FD8AC),
  butter: Color(0xFFFFD37A),
  rose: Color(0xFFFF9B8F),
  periwinkle: Color(0xFF8B93FF),
  dialStart: Color(0xFF8B93FF),
  dialMid: Color(0xFFFFB65C),
  dialEnd: Color(0xFFFF8B7A),
  scrim: Color(0xCC0B0D1F),
  ink: Color(0xFF0E1026),
);

/// Late afternoon into evening: golden hour, warm plum dusk.
const duskPalette = LivyPalette(
  brightness: Brightness.dark,
  night: Color(0xFF241D3C),
  surface: Color(0xFF2E2549),
  surfaceRaised: Color(0xFF382D58),
  surfaceSunken: Color(0xFF1C1730),
  outline: Color(0xFF483A6E),
  amber: Color(0xFFFFAD4D),
  amberDeep: Color(0xFFEE9130),
  coral: Color(0xFFFF8B7A),
  coralDeep: Color(0xFFE9705F),
  cream: Color(0xFFF8F0E1),
  mist: Color(0xFFAFA9CC),
  faint: Color(0xFF7E78A4),
  mint: Color(0xFF8FD8AC),
  butter: Color(0xFFFFD37A),
  rose: Color(0xFFFF9B8F),
  periwinkle: Color(0xFF9BA3FF),
  dialStart: Color(0xFFAF8FFF),
  dialMid: Color(0xFFFFAD4D),
  dialEnd: Color(0xFFFF8B7A),
  scrim: Color(0xCC17122A),
  ink: Color(0xFF1A1530),
);

/// Daytime: illuminated, warm cream sunshine.
const dayPalette = LivyPalette(
  brightness: Brightness.light,
  night: Color(0xFFFAF3E1), // scaffold
  surface: Color(0xFFFFFBF0),
  surfaceRaised: Color(0xFFFFFFFF),
  surfaceSunken: Color(0xFFF0E6CE),
  outline: Color(0xFFE3D6B6),
  amber: Color(0xFFF29C2B), // deeper for contrast on light ground
  amberDeep: Color(0xFFD97F14),
  coral: Color(0xFFE96A57),
  coralDeep: Color(0xFFCC5342),
  cream: Color(0xFF33324F), // primary text: deep warm indigo
  mist: Color(0xFF6E6F8E),
  faint: Color(0xFF9C9DB5),
  mint: Color(0xFF2F9E66),
  butter: Color(0xFFDCA83D),
  rose: Color(0xFFD95F51),
  periwinkle: Color(0xFF5561E0),
  dialStart: Color(0xFF6FA5E8), // morning-sky blue
  dialMid: Color(0xFFF2A83C),
  dialEnd: Color(0xFFE96A57),
  scrim: Color(0xB3352F20),
  ink: Color(0xFF221F3A),
);

/// Semantic color roles, resolved against the active phase palette. Member
/// names are stable across the app; only the values change with the time of
/// day. `applyPhase` is called by ThemeController.
abstract final class LivyColors {
  static LivyPalette _p = nightPalette;
  static ThemePhase _phase = ThemePhase.night;

  static ThemePhase get phase => _phase;
  static LivyPalette get palette => _p;
  static Brightness get brightness => _p.brightness;

  static void applyPhase(ThemePhase phase) {
    _phase = phase;
    _p = switch (phase) {
      ThemePhase.day => dayPalette,
      ThemePhase.dusk => duskPalette,
      ThemePhase.night => nightPalette,
    };
  }

  static Color get night => _p.night;
  static Color get surface => _p.surface;
  static Color get surfaceRaised => _p.surfaceRaised;
  static Color get surfaceSunken => _p.surfaceSunken;
  static Color get outline => _p.outline;
  static Color get amber => _p.amber;
  static Color get amberDeep => _p.amberDeep;
  static Color get coral => _p.coral;
  static Color get coralDeep => _p.coralDeep;
  static Color get cream => _p.cream;
  static Color get mist => _p.mist;
  static Color get faint => _p.faint;
  static Color get mint => _p.mint;
  static Color get butter => _p.butter;
  static Color get rose => _p.rose;
  static Color get periwinkle => _p.periwinkle;
  static Color get dialStart => _p.dialStart;
  static Color get dialMid => _p.dialMid;
  static Color get dialEnd => _p.dialEnd;
  static Color get scrim => _p.scrim;

  /// Always-dark ink for text/icons sitting on amber/coral accent fills —
  /// stays readable in every phase.
  static Color get ink => _p.ink;
}

abstract final class LivySpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class LivyRadius {
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double pill = 999;
}

abstract final class LivyMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 600);
  static const Curve spring = Curves.easeOutBack;
  static const Curve settle = Curves.easeOutCubic;
  static const Curve breathe = Curves.easeInOutSine;
}
