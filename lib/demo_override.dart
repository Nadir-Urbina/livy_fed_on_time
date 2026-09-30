import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A runtime switch for loading the seeded demo household on a build that has
/// Firebase perfectly well configured.
///
/// `SCREENSHOT_DEMO` already does this, but it's a compile-time define, so
/// every change of mind costs a rebuild. This is the same idea for the times
/// you're recording a screen capture and just want sample data now.
///
/// **Debug builds only.** [isOn] hard-returns false in release regardless of
/// what's stored, so a released app can never be talked into throwing away a
/// real household's records — not by a stale preference, not by a restored
/// backup, not by anything.
abstract final class DemoOverride {
  static const _key = 'force_demo_mode';

  /// Whether this launch should ignore Firebase and seed the demo household.
  static Future<bool> isOn() async {
    if (!kDebugMode) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Takes effect on the next launch — the repository is chosen once, during
  /// startup, so there's nothing sensible to swap underneath a running app.
  static Future<void> set(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
  }
}
