import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/onboarding/application/onboarding_controller.dart';
import 'package:aaspaas/features/onboarding/data/repositories/onboarding_repository.dart';
import '../auth/auth_controller_test.dart';

class FakeOnboardingRepository extends OnboardingRepository {
  FakeOnboardingRepository() : super(Dio());

  @override
  Future<UserEntity> completeOnboarding({
    required String displayName,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
    String? avatarUrl,
  }) async {
    return UserEntity(
      id: 'usr-onboarded',
      phoneNumber: '+91 ••••••3210',
      displayName: displayName,
      onboardingCompleted: true,
      countryCode: countryCode ?? 'IN',
      city: city,
      locality: locality,
      neighborhood: neighborhood,
    );
  }
}

void main() {
  late AuthController authController;
  late FakeOnboardingRepository onboardingRepo;
  late OnboardingController onboardingController;

  setUp(() {
    final fakeStorage = FakeSecureStorageService();
    final fakeAuthRepo = FakeAuthRepository();
    authController = AuthController(
      authRepository: fakeAuthRepo,
      secureStorage: fakeStorage,
    );
    onboardingRepo = FakeOnboardingRepository();
    onboardingController = OnboardingController(
      onboardingRepository: onboardingRepo,
      authController: authController,
    );
  });

  test('setDisplayName updates form state', () {
    onboardingController.setDisplayName('Sujeet Sharma');
    expect(onboardingController.state.displayName, 'Sujeet Sharma');
  });

  test('setLocality updates form state', () {
    const loc = LocalitySuggestion(
      id: 'loc-1',
      countryCode: 'IN',
      state: 'Karnataka',
      district: 'Bengaluru Urban',
      city: 'Bengaluru',
      locality: 'Indiranagar',
    );

    onboardingController.setLocality(loc);
    expect(
      onboardingController.state.selectedLocality?.locality,
      'Indiranagar',
    );
    expect(onboardingController.state.selectedLocality?.city, 'Bengaluru');
  });

  test('submitOnboarding transitions AuthController to AuthAuthenticated',
      () async {
    onboardingController.setDisplayName('Sujeet Sharma');
    onboardingController.setLocality(
      const LocalitySuggestion(
        id: 'loc-1',
        countryCode: 'IN',
        state: 'Karnataka',
        district: 'Bengaluru Urban',
        city: 'Bengaluru',
        locality: 'Indiranagar',
      ),
    );

    final user = await onboardingController.submitOnboarding();

    expect(user.displayName, 'Sujeet Sharma');
    expect(user.onboardingCompleted, true);
    expect(authController.state, isA<AuthAuthenticated>());
  });
}
