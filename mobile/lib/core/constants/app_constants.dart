/// Application-wide string constants.
///
/// Do not put user-facing display strings here — those belong in
/// localization ARB files (lib/l10n/).
/// This file is for internal identifiers and technical constants.
class AppConstants {
  AppConstants._();

  // ── API ────────────────────────────────────────────────────────────────────

  /// Default network request timeout (connect + receive).
  static const Duration networkTimeout = Duration(seconds: 30);

  /// Default connect timeout.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Default receive timeout.
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Storage keys ──────────────────────────────────────────────────────────

  /// Key for the JWT access token in secure storage.
  static const String accessTokenKey = 'access_token';

  /// Key for the JWT refresh token in secure storage.
  static const String refreshTokenKey = 'refresh_token';

  /// Key for the current user ID in local storage.
  static const String userIdKey = 'user_id';

  /// Key for the selected theme preference.
  static const String themeModeKey = 'theme_mode';

  // ── App metadata ──────────────────────────────────────────────────────────

  static const String appName = 'Aaspaas';
  static const String appTagline = 'Your Local World, In One App.';
}
