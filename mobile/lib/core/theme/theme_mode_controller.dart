import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage_service.dart';

/// Manages and persists the active application [ThemeMode].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._localStorage)
      : super(_loadInitialMode(_localStorage));

  final LocalStorageService _localStorage;

  static ThemeMode _loadInitialMode(LocalStorageService storage) {
    final savedMode = storage.readThemeMode();
    return switch (savedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Update the active theme mode and persist to local storage.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _localStorage.saveThemeMode(modeString);
  }

  /// Cycles between System -> Light -> Dark -> System.
  Future<void> toggleTheme() async {
    final nextMode = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    await setThemeMode(nextMode);
  }
}

/// Riverpod provider for the application [ThemeMode].
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ThemeModeNotifier(storage);
});
