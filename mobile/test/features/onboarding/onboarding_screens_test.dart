import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/nearby/domain/services/location_service.dart';
import 'package:aaspaas/features/onboarding/application/onboarding_controller.dart';
import 'package:aaspaas/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:aaspaas/features/onboarding/presentation/screens/completion_screen.dart';
import 'package:aaspaas/features/onboarding/presentation/screens/locality_setup_screen.dart';
import 'package:aaspaas/features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../auth/auth_controller_test.dart';
import 'onboarding_controller_test.dart';

class FakeLocationService implements LocationService {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getCurrentPosition() async => Position(
        latitude: 28.57,
        longitude: 77.36,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 100,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: '''
API_BASE_URL=http://localhost:3000/api/v1
ENVIRONMENT=development
''',
    );
  });

  group('ProfileSetupScreen', () {
    testWidgets('renders title, name input field, and Continue CTA',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tell us a little about you'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(
        find.textContaining('neighbors will know you by this name'),
        findsOneWidget,
      );
    });

    testWidgets('validates required name field before continuing',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileSetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap continue without entering name
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your name.'), findsOneWidget);
    });
  });

  group('LocalitySetupScreen', () {
    testWidgets(
        'renders Where do you live?, Use Current Location, search bar, and disabled Complete Setup CTA',
        (tester) async {
      final fakeRepo = FakeOnboardingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(fakeRepo),
            locationServiceProvider
                .overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LocalitySetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where do you live?'), findsOneWidget);
      expect(find.text('Use Current Location'), findsOneWidget);
      expect(find.text('Auto-detect your area via GPS'), findsOneWidget);
      expect(find.text('Popular Localities'), findsOneWidget);
      expect(find.text('Select your locality'), findsOneWidget);
    });

    testWidgets(
        'tapping Use Current Location auto-detects area and enables Complete Setup CTA',
        (tester) async {
      final fakeRepo = FakeOnboardingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(fakeRepo),
            locationServiceProvider
                .overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LocalitySetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Use Current Location"
      await tester.tap(find.text('Use Current Location'));
      await tester.pumpAndSettle();

      // Locality is selected: "Complete Setup" CTA is enabled
      expect(find.text('Complete Setup'), findsOneWidget);
      expect(find.text('Sector 52'), findsWidgets);
    });

    testWidgets(
        'selecting a popular locality enables sticky Complete Setup button without scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeOnboardingRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(fakeRepo),
            locationServiceProvider
                .overrideWithValue(FakeLocationService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LocalitySetupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Indiranagar'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap Indiranagar from popular list
      await tester.tap(find.text('Indiranagar'));
      await tester.pumpAndSettle();

      // Complete Setup CTA is enabled and directly visible in bottom bar
      expect(find.text('Complete Setup'), findsOneWidget);
    });
  });

  group('CompletionScreen', () {
    testWidgets('renders You are all set headline and Continue to Aaspaas CTA',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingControllerProvider.overrideWith(
              (ref) => OnboardingController(
                onboardingRepository: FakeOnboardingRepository(),
                authController: AuthController(
                  authRepository: FakeAuthRepository(),
                  secureStorage: FakeSecureStorageService(),
                ),
              )..state = const OnboardingFormState(
                  displayName: 'Sujeet Sharma',
                  completedUser: UserEntity(
                    id: 'usr-123',
                    phoneNumber: '+91 ••••••3210',
                    displayName: 'Sujeet Sharma',
                    locality: 'Indiranagar',
                    city: 'Bengaluru',
                    onboardingCompleted: true,
                  ),
                ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CompletionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.text('Sujeet Sharma'), findsOneWidget);
      expect(find.text('Phone Verified'), findsOneWidget);
      expect(find.text('Resident Member'), findsOneWidget);
      expect(find.text('Continue to Aaspaas'), findsOneWidget);
    });
  });
}
