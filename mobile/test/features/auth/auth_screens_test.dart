import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/presentation/screens/welcome_screen.dart';
import 'package:aaspaas/features/auth/presentation/screens/phone_input_screen.dart';
import 'package:aaspaas/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:aaspaas/features/auth/presentation/widgets/otp_pin_input.dart';

Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
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

  group('WelcomeScreen', () {
    testWidgets('renders Aaspaas branding, tagline, and Get Started CTA',
        (tester) async {
      await tester.pumpWidget(createTestApp(const WelcomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Aaspaas'), findsOneWidget);
      expect(find.text('Your Local World, In One App.'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Verified Local Community'), findsOneWidget);
      expect(find.text('Privacy First'), findsOneWidget);
    });
  });

  group('PhoneInputScreen', () {
    testWidgets(
        'renders title, country code +91, phone input, and Continue button',
        (tester) async {
      await tester.pumpWidget(createTestApp(const PhoneInputScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Enter your mobile number'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('validates empty or invalid phone number on Continue',
        (tester) async {
      await tester.pumpWidget(createTestApp(const PhoneInputScreen()));
      await tester.pumpAndSettle();

      // Tap continue with empty field
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Mobile number is required.'), findsOneWidget);

      // Enter invalid length number
      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a 10-digit mobile number.'),
        findsOneWidget,
      );
    });
  });

  group('OtpVerificationScreen & OtpPinInput', () {
    testWidgets('renders masked phone, 6 digit inputs, and resend timer',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const OtpVerificationScreen(
            phoneNumber: '+919876543210',
            maskedPhoneNumber: '+91 ••••••3210',
            initialDevOtp: '123456',
            cooldownSeconds: 60,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify your number'), findsOneWidget);
      expect(
        find.textContaining('+91 ••••••3210'),
        findsOneWidget,
      );
      expect(find.text('Verify and Continue'), findsOneWidget);
      expect(find.text('Resend code in 60s'), findsOneWidget);
      expect(find.byType(OtpPinInput), findsOneWidget);

      // Verify 6 input fields are present
      expect(find.byType(TextFormField), findsNWidgets(6));
    });

    testWidgets('OtpPinInput triggers onCompleted when 6 digits entered',
        (tester) async {
      String completedCode = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpPinInput(
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));

      // Enter digits sequentially
      await tester.enterText(fields.at(0), '1');
      await tester.enterText(fields.at(1), '2');
      await tester.enterText(fields.at(2), '3');
      await tester.enterText(fields.at(3), '4');
      await tester.enterText(fields.at(4), '5');
      await tester.enterText(fields.at(5), '6');
      await tester.pumpAndSettle();

      expect(completedCode, '123456');
    });
  });
}
