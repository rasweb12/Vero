import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vero/shared/providers/theme_mode_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme survives controller recreation for all modes', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = ThemeModeController(preferences);
    addTearDown(controller.dispose);
    expect(controller.state, ThemeMode.system);
    for (final mode in ThemeMode.values) {
      await controller.setThemeMode(mode);
      final restored = ThemeModeController(preferences);
      expect(restored.state, mode);
      restored.dispose();
    }
  });

  test('unknown preference falls back to system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'invalid'});
    final controller = ThemeModeController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(controller.dispose);
    expect(controller.state, ThemeMode.system);
  });
}
