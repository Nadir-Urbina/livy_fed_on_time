import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Livy type roles:
///  - Fraunces: warm display serif for headlines and hero numbers
///  - Space Grotesk: clean utility face for numerals and data
///  - Nunito Sans: friendly body copy
/// Colors default to the active phase palette at call time.
abstract final class LivyType {
  static TextStyle display({double size = 34, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.fraunces(fontSize: size, color: color ?? LivyColors.cream, fontWeight: weight, height: 1.15);

  static TextStyle data({double size = 16, Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, color: color ?? LivyColors.cream, fontWeight: weight, height: 1.2);

  static TextStyle body({double size = 15, Color? color, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.nunitoSans(fontSize: size, color: color ?? LivyColors.cream, fontWeight: weight, height: 1.45);

  static TextStyle label({double size = 12, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.nunitoSans(fontSize: size, color: color ?? LivyColors.mist, fontWeight: weight, letterSpacing: 1.1, height: 1.2);
}

ThemeData buildLivyTheme() {
  final dark = LivyColors.brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: LivyColors.brightness,
    primary: LivyColors.amber,
    onPrimary: LivyColors.ink,
    secondary: LivyColors.coral,
    onSecondary: dark ? LivyColors.night : LivyColors.surfaceRaised,
    surface: LivyColors.surface,
    onSurface: LivyColors.cream,
    surfaceContainerHighest: LivyColors.surfaceRaised,
    error: LivyColors.rose,
    onError: dark ? LivyColors.night : LivyColors.surfaceRaised,
    outline: LivyColors.outline,
  );

  final base = ThemeData(
    brightness: LivyColors.brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: LivyColors.night,
    colorScheme: scheme,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: LivyType.display(size: 40),
      displayMedium: LivyType.display(size: 34),
      displaySmall: LivyType.display(size: 28),
      headlineMedium: LivyType.display(size: 24),
      headlineSmall: LivyType.display(size: 20),
      titleLarge: LivyType.body(size: 18, weight: FontWeight.w700),
      titleMedium: LivyType.body(size: 16, weight: FontWeight.w700),
      bodyLarge: LivyType.body(size: 16),
      bodyMedium: LivyType.body(),
      bodySmall: LivyType.body(size: 13, color: LivyColors.mist),
      labelLarge: LivyType.label(size: 14),
      labelMedium: LivyType.label(),
      labelSmall: LivyType.label(size: 11),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: LivyType.display(size: 22),
      iconTheme: IconThemeData(color: LivyColors.cream),
    ),
    cardTheme: CardThemeData(
      color: LivyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(LivyRadius.md)),
        side: BorderSide(color: LivyColors.outline, width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LivyColors.amber,
        foregroundColor: LivyColors.ink,
        minimumSize: const Size(64, 54),
        textStyle: LivyType.body(size: 16, weight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LivyRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LivyColors.cream,
        minimumSize: const Size(64, 54),
        side: BorderSide(color: LivyColors.outline, width: 1.5),
        textStyle: LivyType.body(size: 16, weight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LivyRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LivyColors.periwinkle,
        textStyle: LivyType.body(size: 15, weight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LivyColors.surfaceSunken,
      hintStyle: LivyType.body(color: LivyColors.faint),
      labelStyle: LivyType.body(color: LivyColors.mist),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        borderSide: BorderSide(color: LivyColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        borderSide: BorderSide(color: LivyColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LivyRadius.sm),
        borderSide: BorderSide(color: LivyColors.amber, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: LivyColors.surfaceRaised,
      modalBackgroundColor: LivyColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LivyRadius.lg)),
      ),
      showDragHandle: true,
      dragHandleColor: LivyColors.outline,
    ),
    dividerTheme: DividerThemeData(color: LivyColors.outline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LivyColors.surfaceRaised,
      contentTextStyle: LivyType.body(),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(LivyRadius.sm)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LivyColors.ink : LivyColors.mist),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? LivyColors.amber : LivyColors.surfaceSunken),
      trackOutlineColor: WidgetStatePropertyAll(LivyColors.outline),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LivyColors.surfaceSunken,
      indicatorColor: LivyColors.amber.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(LivyType.body(size: 11, color: LivyColors.mist, weight: FontWeight.w700)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? LivyColors.amber : LivyColors.faint)),
    ),
  );
}
