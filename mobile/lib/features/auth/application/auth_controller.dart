import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/entities/user_entity.dart';
import 'auth_state.dart';

/// StateNotifier controlling the authentication workflow, session persistence, and logout.
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository authRepository,
    required SecureStorageService secureStorage,
  })  : _authRepository = authRepository,
        _secureStorage = secureStorage,
        super(const AuthInitial()) {
    checkAuthStatus();
  }

  final AuthRepository _authRepository;
  final SecureStorageService _secureStorage;

  /// Check whether a valid session exists in secure storage at startup.
  Future<void> checkAuthStatus() async {
    final token = await _secureStorage.readAccessToken();
    final refreshToken = await _secureStorage.readRefreshToken();

    if (token == null && refreshToken == null) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final user = await _authRepository.getMe();
      if (user.onboardingCompleted) {
        state = AuthAuthenticated(user);
      } else {
        state = AuthOnboardingRequired(user);
      }
    } catch (_) {
      // If fetching user profile failed (e.g. invalid/expired token), clear and reset
      await _secureStorage.clearAuthTokens();
      state = const AuthUnauthenticated();
    }
  }

  /// Request a 6-digit OTP for the given phone number.
  Future<OtpRequestResult> requestOtp(String phoneNumber) async {
    return _authRepository.requestOtp(phoneNumber);
  }

  /// Verify 6-digit OTP code and persist session credentials.
  Future<void> verifyOtp({
    required String phoneNumber,
    required String otp,
    Map<String, dynamic>? deviceMetadata,
  }) async {
    state = const AuthAuthenticating();
    try {
      final result = await _authRepository.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
        deviceMetadata: deviceMetadata,
      );

      // Securely store credentials in EncryptedSharedPreferences / Keychain
      await _secureStorage.saveAccessToken(result.tokens.accessToken);
      await _secureStorage.saveRefreshToken(result.tokens.refreshToken);

      if (result.user.onboardingCompleted) {
        state = AuthAuthenticated(result.user);
      } else {
        state = AuthOnboardingRequired(result.user);
      }
    } catch (e) {
      state = AuthError(e.toString());
      rethrow;
    }
  }

  /// Revoke session, clear secure storage, and transition to unauthenticated state.
  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Best effort network revocation
    } finally {
      await _secureStorage.clearAuthTokens();
      state = const AuthUnauthenticated();
    }
  }

  /// Update the current authenticated user instance (e.g. after onboarding completion).
  void updateUser(UserEntity updatedUser) {
    if (updatedUser.onboardingCompleted) {
      state = AuthAuthenticated(updatedUser);
    } else {
      state = AuthOnboardingRequired(updatedUser);
    }
  }
}

/// Riverpod provider for [AuthController].
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AuthController(
    authRepository: authRepository,
    secureStorage: secureStorage,
  );
});
