import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/onboarding/application/onboarding_controller.dart';
import 'package:aaspaas/features/onboarding/presentation/screens/profile_setup_screen.dart';
import 'package:aaspaas/features/onboarding/presentation/screens/completion_screen.dart';
import '../auth/auth_controller_test.dart';
import 'onboarding_controller_test.dart';

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
      expect(find.text('Indiranagar, Bengaluru'), findsOneWidget);
      expect(find.text('Verified Member'), findsOneWidget);
      expect(find.text('Continue to Aaspaas'), findsOneWidget);
    });
  });
}
