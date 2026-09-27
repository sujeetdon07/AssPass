import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/storage/secure_storage_service.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/data/models/auth_tokens_model.dart';
import 'package:aaspaas/features/auth/data/repositories/auth_repository.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';

class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService() : super(const FlutterSecureStorage());

  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio());

  UserEntity? meResult;
  bool shouldThrowMe = false;

  @override
  Future<UserEntity> getMe() async {
    if (shouldThrowMe) throw Exception('Unauthorized');
    return meResult ??
        const UserEntity(
          id: 'usr-1',
          phoneNumber: '+91 ••••••3210',
          displayName: 'Test User',
          onboardingCompleted: true,
        );
  }

  @override
  Future<OtpRequestResult> requestOtp(String phoneNumber) async {
    return const OtpRequestResult(
      message: 'OTP sent',
      maskedPhoneNumber: '+91 ••••••3210',
      cooldownSeconds: 60,
      expiresInSeconds: 300,
      devOtp: '123456',
    );
  }

  @override
  Future<AuthResult> verifyOtp({
    required String phoneNumber,
    required String otp,
    Map<String, dynamic>? deviceMetadata,
  }) async {
    if (otp == '000000') throw Exception('Invalid OTP code');
    return const AuthResult(
      user: UserEntity(
        id: 'usr-new',
        phoneNumber: '+91 ••••••3210',
        onboardingCompleted: false,
      ),
      tokens: AuthTokensModel(
        accessToken: 'access-token-123',
        refreshToken: 'refresh-token-456',
        expiresIn: 900,
      ),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<UserEntity> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
  }) async {
    return UserEntity(
      id: 'usr-1',
      phoneNumber: '+91 ••••••3210',
      displayName: displayName ?? 'Updated User',
      bio: bio,
      avatarUrl: avatarUrl,
      countryCode: countryCode ?? 'IN',
      state: state,
      district: district,
      city: city,
      locality: locality,
      neighborhood: neighborhood,
      onboardingCompleted: true,
    );
  }
}

void main() {
  late FakeSecureStorageService fakeStorage;
  late FakeAuthRepository fakeRepo;
  late AuthController controller;

  setUp(() {
    fakeStorage = FakeSecureStorageService();
    fakeRepo = FakeAuthRepository();
  });

  test('defaults to AuthUnauthenticated when no tokens in storage', () async {
    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );

    // Initial check triggers asynchronously in constructor
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<AuthUnauthenticated>());
  });

  test('restores AuthAuthenticated session when valid token exists', () async {
    await fakeStorage.saveAccessToken('existing-token');
    await fakeStorage.saveRefreshToken('existing-refresh');

    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );

    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<AuthAuthenticated>());
    final state = controller.state as AuthAuthenticated;
    expect(state.user.id, 'usr-1');
  });

  test('restores AuthOnboardingRequired when user has not completed onboarding',
      () async {
    await fakeStorage.saveAccessToken('existing-token');
    await fakeStorage.saveRefreshToken('existing-refresh');
    fakeRepo.meResult = const UserEntity(
      id: 'usr-2',
      phoneNumber: '+91 ••••••5678',
      onboardingCompleted: false,
    );

    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );

    await Future<void>.delayed(Duration.zero);
    expect(controller.state, isA<AuthOnboardingRequired>());
  });

  test('verifyOtp saves tokens and transitions to AuthOnboardingRequired',
      () async {
    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );
    await Future<void>.delayed(Duration.zero);

    await controller.verifyOtp(phoneNumber: '+919876543210', otp: '123456');

    expect(controller.state, isA<AuthOnboardingRequired>());
    expect(await fakeStorage.readAccessToken(), 'access-token-123');
    expect(await fakeStorage.readRefreshToken(), 'refresh-token-456');
  });

  test('logout clears secure tokens and transitions to AuthUnauthenticated',
      () async {
    await fakeStorage.saveAccessToken('token-to-clear');
    await fakeStorage.saveRefreshToken('refresh-to-clear');

    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );
    await Future<void>.delayed(Duration.zero);

    await controller.logout();

    expect(controller.state, isA<AuthUnauthenticated>());
    expect(await fakeStorage.readAccessToken(), isNull);
    expect(await fakeStorage.readRefreshToken(), isNull);
  });

  test('updateProfile updates user and transitions to AuthAuthenticated',
      () async {
    controller = AuthController(
      authRepository: fakeRepo,
      secureStorage: fakeStorage,
    );
    await Future<void>.delayed(Duration.zero);

    final updated = await controller.updateProfile(
      displayName: 'Sujeet Sharma',
      bio: 'Neighbor in Sector 52',
      locality: 'Sector 52',
      city: 'Noida',
    );

    expect(updated.displayName, 'Sujeet Sharma');
    expect(updated.bio, 'Neighbor in Sector 52');
    expect(controller.state, isA<AuthAuthenticated>());
    final authState = controller.state as AuthAuthenticated;
    expect(authState.user.displayName, 'Sujeet Sharma');
    expect(authState.user.bio, 'Neighbor in Sector 52');
  });
}
