import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Provides a configured [SharedPreferences] instance.
///
/// Must be overridden in the ProviderScope before use, since
/// SharedPreferences.getInstance() is async. Override in main.dart
/// after awaiting the instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope. '
    'Call SharedPreferences.getInstance() in main() and pass it as an override.',
  );
});

/// Abstraction over [SharedPreferences] for non-sensitive local settings.
///
/// Use this for:
/// - Theme mode preference
/// - Onboarding completion flag
/// - Non-sensitive user preferences
///
/// NEVER use this for tokens or sensitive credentials — use [SecureStorageService].
class LocalStorageService {
  const LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  // ── Generic operations ─────────────────────────────────────────────────────

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);

  String? getString(String key) => _prefs.getString(key);

  Future<bool> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  bool? getBool(String key) => _prefs.getBool(key);

  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  Future<bool> remove(String key) => _prefs.remove(key);

  // ── Domain-specific helpers ────────────────────────────────────────────────

  /// Save the theme mode preference.
  /// Values: 'system' | 'light' | 'dark'
  Future<bool> saveThemeMode(String mode) =>
      setString(AppConstants.themeModeKey, mode);

  /// Read the saved theme mode. Returns null if not set.
  String? readThemeMode() => getString(AppConstants.themeModeKey);
}

/// Riverpod provider for [LocalStorageService].
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalStorageService(prefs);
});
