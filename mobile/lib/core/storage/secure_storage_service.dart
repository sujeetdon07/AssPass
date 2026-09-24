import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Provides a configured [FlutterSecureStorage] instance.
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

/// Abstraction over [FlutterSecureStorage] for sensitive data.
///
/// Use this for:
/// - JWT access tokens
/// - JWT refresh tokens
/// - Any session credentials
///
/// Never store sensitive data in [LocalStorageService].
class SecureStorageService {
  const SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  /// Write a value to secure storage.
  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a value from secure storage. Returns null if not found.
  Future<String?> read({required String key}) async {
    return _storage.read(key: key);
  }

  /// Delete a single key from secure storage.
  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  /// Delete all keys from secure storage.
  /// Used during logout to clear all session data.
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // ── Token helpers ──────────────────────────────────────────────────────────

  /// Save the JWT access token.
  Future<void> saveAccessToken(String token) =>
      write(key: AppConstants.accessTokenKey, value: token);

  /// Read the JWT access token.
  Future<String?> readAccessToken() => read(key: AppConstants.accessTokenKey);

  /// Save the JWT refresh token.
  Future<void> saveRefreshToken(String token) =>
      write(key: AppConstants.refreshTokenKey, value: token);

  /// Read the JWT refresh token.
  Future<String?> readRefreshToken() => read(key: AppConstants.refreshTokenKey);

  /// Clear all auth tokens. Called on logout.
  Future<void> clearAuthTokens() async {
    await delete(key: AppConstants.accessTokenKey);
    await delete(key: AppConstants.refreshTokenKey);
  }
}

/// Riverpod provider for [SecureStorageService].
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  return SecureStorageService(storage);
});
