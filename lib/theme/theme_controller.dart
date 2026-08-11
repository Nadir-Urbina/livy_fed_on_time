import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

enum ThemeOverride { auto, day, dusk, night }

/// Drives the time-adaptive theme: sunny by day, golden at dusk, deep indigo
/// at night. Checks the clock every minute; users can pin a phase from
/// Mascot & settings ("Auto" follows the sun).
///
/// Fresh installs open on the night palette — most first launches happen in
/// the small hours, and the dark theme is the gentler one to meet at 3am.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static const _prefKey = 'livy.themeOverride';
  static const _defaultMode = ThemeOverride.night;

  ThemeOverride _overrideMode = _defaultMode;
  Timer? _timer;
  late SharedPreferences _prefs;

  ThemeOverride get overrideMode => _overrideMode;
  ThemePhase get phase => LivyColors.phase;

  static Future<ThemeController> create() async {
    final c = ThemeController._();
    c._prefs = await SharedPreferences.getInstance();
    c._overrideMode = ThemeOverride.values
            .asNameMap()[c._prefs.getString(_prefKey)] ??
        _defaultMode;
    LivyColors.applyPhase(c._effectivePhase());
    c._timer = Timer.periodic(const Duration(minutes: 1), (_) => c._tick());
    return c;
  }

  ThemePhase _effectivePhase() => switch (_overrideMode) {
        ThemeOverride.auto => phaseForTime(DateTime.now()),
        ThemeOverride.day => ThemePhase.day,
        ThemeOverride.dusk => ThemePhase.dusk,
        ThemeOverride.night => ThemePhase.night,
      };

  void _tick() {
    final next = _effectivePhase();
    if (next != LivyColors.phase) {
      LivyColors.applyPhase(next);
      notifyListeners();
    }
  }

  Future<void> setOverride(ThemeOverride value) async {
    _overrideMode = value;
    await _prefs.setString(_prefKey, value.name);
    LivyColors.applyPhase(_effectivePhase());
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
