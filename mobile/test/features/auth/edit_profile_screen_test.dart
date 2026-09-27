import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/shell/presentation/screens/profile_screen.dart';
import 'package:aaspaas/features/shell/presentation/screens/edit_profile_screen.dart';
import 'auth_controller_test.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: '''
API_BASE_URL=http://localhost:3000/api/v1
ENVIRONMENT=development
''',
    );
  });

  group('ProfileScreen User Card & Verification Tests', () {
    testWidgets(
        'renders user name, phone verified badge, resident member badge, and Edit Profile CTA',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final fakeRepo = FakeAuthRepository();
      const user = UserEntity(
        id: 'usr-1',
        phoneNumber: '+91 ••••••3210',
        displayName: 'Sujeet Sharma',
        bio: 'Resident of Sector 52 for 3 years',
        isPhoneVerified: true,
        locality: 'Sector 52',
        city: 'Noida',
        onboardingCompleted: true,
      );
      fakeRepo.meResult = user;

      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveAccessToken('token');

      final authController = AuthController(
        authRepository: fakeRepo,
        secureStorage: fakeStorage,
      )..state = const AuthAuthenticated(user);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sujeet Sharma'), findsOneWidget);
      expect(find.text('Sector 52, Noida'), findsOneWidget);
      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.text('Resident Member'), findsOneWidget);
      expect(find.text('Resident of Sector 52 for 3 years'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });

  group('EditProfileScreen Widget Tests', () {
    testWidgets('renders Edit Profile form with initial values and Save Changes button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final fakeRepo = FakeAuthRepository();
      const user = UserEntity(
        id: 'usr-1',
        phoneNumber: '+91 ••••••3210',
        displayName: 'Sujeet Sharma',
        bio: 'Gardening enthusiast',
        isPhoneVerified: true,
        locality: 'Sector 52',
        city: 'Noida',
        onboardingCompleted: true,
      );
      fakeRepo.meResult = user;

      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveAccessToken('token');

      final authController = AuthController(
        authRepository: fakeRepo,
        secureStorage: fakeStorage,
      )..state = const AuthAuthenticated(user);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Profile Photo'), findsOneWidget);
      expect(find.text('Sujeet Sharma'), findsOneWidget);
      expect(find.text('Gardening enthusiast'), findsOneWidget);
      expect(find.text('Sector 52, Noida'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Member Verification Status'), findsOneWidget);
      expect(find.text('Phone Verified (OTP)'), findsOneWidget);
    });
  });
}
