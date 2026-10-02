import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) {
    final sharedPreferences = ref.watch(sharedPreferencesProvider);

    return ThemeModeController(sharedPreferences);
  },
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._sharedPreferences)
    : super(_readThemeMode(_sharedPreferences));

  static const _storageKey = 'theme_mode';

  final SharedPreferences _sharedPreferences;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    state = themeMode;
    await _sharedPreferences.setString(_storageKey, themeMode.name);
  }

  static ThemeMode _readThemeMode(SharedPreferences sharedPreferences) {
    final storedValue = sharedPreferences.getString(_storageKey);

    return ThemeMode.values.firstWhere(
      (themeMode) => themeMode.name == storedValue,
      orElse: () => ThemeMode.system,
    );
  }
}
