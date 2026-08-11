import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livy_fed_on_time/theme/theme_controller.dart';
import 'package:livy_fed_on_time/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController default', () {
    test('a fresh install opens on the night palette', () async {
      // No stored preference — exactly what a first launch sees.
      SharedPreferences.setMockInitialValues({});

      final c = await ThemeController.create();
      addTearDown(c.dispose);

      expect(c.overrideMode, ThemeOverride.night);
      expect(LivyColors.phase, ThemePhase.night);
      expect(LivyColors.brightness, Brightness.dark);
      // The scaffold color the onboarding hero sits on.
      expect(LivyColors.night, nightPalette.night);
    });

    test('a stored choice still wins over the default', () async {
      SharedPreferences.setMockInitialValues({'livy.themeOverride': 'auto'});

      final c = await ThemeController.create();
      addTearDown(c.dispose);

      expect(c.overrideMode, ThemeOverride.auto);
      expect(LivyColors.phase, phaseForTime(DateTime.now()));
    });
  });
}
