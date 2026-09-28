import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aaspaas/core/routing/app_router.dart';
import 'package:aaspaas/core/services/app_share_service.dart';
import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/data/repositories/auth_repository.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/messaging/domain/entities/conversation_entity.dart';
import 'package:aaspaas/features/messaging/presentation/widgets/conversation_list_tile.dart';
import 'package:aaspaas/features/shell/presentation/screens/edit_profile_screen.dart';
import 'package:aaspaas/features/shell/presentation/screens/profile_screen.dart';
import 'package:aaspaas/features/shell/presentation/screens/public_profile_screen.dart';
import 'package:aaspaas/features/shell/presentation/screens/user_search_screen.dart';

import 'auth_controller_test.dart';

class MockSearchAuthRepository extends FakeAuthRepository {
  MockSearchAuthRepository({
    this.searchResultUsers = const [],
    this.usernameUser,
  });

  final List<UserSearchResult> searchResultUsers;
  final UserEntity? usernameUser;

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final clean = query.trim().replaceAll('@', '').toLowerCase();
    return searchResultUsers
        .where(
          (u) =>
              (u.username != null &&
                  u.username!.toLowerCase().contains(clean)) ||
              u.displayName.toLowerCase().contains(clean),
        )
        .toList();
  }

  @override
  Future<UserEntity> getUserByUsername(String username) async {
    final clean = username.trim().replaceAll('@', '').toLowerCase();
    if (usernameUser != null &&
        usernameUser!.username?.toLowerCase() == clean) {
      return usernameUser!;
    }
    throw Exception('User not found');
  }
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

  group('Username Entity & Presentation Tests', () {
    test('UserEntity handle formatting and backward compatibility', () {
      // User with username
      const userWithHandle = UserEntity(
        id: 'usr-1',
        phoneNumber: '+91 ••••••3210',
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
      );
      expect(userWithHandle.username, equals('sujeet'));
      expect(userWithHandle.handle, equals('@sujeet'));

      // Backward compatible user without username
      const userWithoutHandle = UserEntity(
        id: 'usr-2',
        phoneNumber: '+91 ••••••3210',
        displayName: 'Existing User',
      );
      expect(userWithoutHandle.username, isNull);
      expect(userWithoutHandle.handle, isNull);

      // copyWith updates username cleanly
      final updated = userWithoutHandle.copyWith(username: 'new_handle');
      expect(updated.username, equals('new_handle'));
      expect(updated.handle, equals('@new_handle'));
      expect(updated.id, equals('usr-2')); // User ID immutable
    });

    test('ConversationParticipantProfile formats handle cleanly', () {
      const participant = ConversationParticipantProfile(
        id: 'usr-10',
        displayName: 'Sujeet',
        username: 'sujeet_dev',
      );
      expect(participant.handle, equals('@sujeet_dev'));

      const legacyParticipant = ConversationParticipantProfile(
        id: 'usr-11',
        displayName: 'Old Neighbor',
      );
      expect(legacyParticipant.handle, isNull);
    });
  });

  group('AppShareService Profile Sharing Tests', () {
    test('buildProfilePayload generates Instagram-style @username deep link', () {
      final payloadWithHandle = AppShareService.buildProfilePayload(
        displayName: 'Sujeet Kumar',
        username: 'sujeet',
        locality: 'Indiranagar, Bengaluru',
      );

      expect(payloadWithHandle.contentType, equals(ShareContentType.profile));
      expect(payloadWithHandle.title, equals('Sujeet Kumar on Aaspaas'));
      expect(payloadWithHandle.url, contains('/@sujeet'));
      expect(payloadWithHandle.formattedText, contains('Check out Sujeet Kumar on Aaspaas'));
      expect(payloadWithHandle.formattedText, contains('@sujeet'));

      // Backward compatibility for users without username
      final payloadWithoutHandle = AppShareService.buildProfilePayload(
        displayName: 'Sujeet Kumar',
        locality: 'Indiranagar, Bengaluru',
      );
      expect(payloadWithoutHandle.url, contains('/profile'));
    });
  });

  group('Profile Screen Username Display Tests', () {
    testWidgets('shows display name as primary and @username as secondary',
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
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
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

      expect(find.text('Sujeet Kumar'), findsOneWidget);
      expect(find.text('@sujeet'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('prompts to set username if user has none', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final fakeRepo = FakeAuthRepository();
      const user = UserEntity(
        id: 'usr-2',
        phoneNumber: '+91 ••••••3210',
        displayName: 'Legacy User',
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

      expect(find.text('Legacy User'), findsOneWidget);
      expect(find.text('+ Set @username'), findsOneWidget);
    });
  });

  group('EditProfileScreen Username Setup Tests', () {
    testWidgets('renders Username field with @ prefix and availability status',
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
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
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
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('@'), findsOneWidget);
      expect(find.text('sujeet'), findsOneWidget);
      expect(find.text('✓ Your current username'), findsOneWidget);
    });
  });

  group('UserSearchScreen Tests', () {
    testWidgets('searches neighbors by username and displays avatar & handle without phone',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockSearchAuthRepository(
        searchResultUsers: const [
          UserSearchResult(
            id: 'usr-101',
            username: 'sujeet',
            displayName: 'Sujeet Kumar',
            locality: 'Indiranagar',
            city: 'Bengaluru',
          ),
          UserSearchResult(
            id: 'usr-102',
            username: 'sujeet_sharma',
            displayName: 'Sujeet Sharma',
            locality: 'Sector 52',
            city: 'Noida',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const UserSearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find Neighbors'), findsOneWidget);

      // Enter search term
      await tester.enterText(find.byType(TextField), '@sujeet');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Sujeet Kumar'), findsOneWidget);
      expect(find.text('@sujeet'), findsWidgets);
      expect(find.text('Sujeet Sharma'), findsOneWidget);
      expect(find.text('@sujeet_sharma'), findsOneWidget);

      // Verify privacy: phone number is NEVER rendered
      expect(find.textContaining('+91'), findsNothing);
    });
  });

  group('PublicProfileScreen Tests', () {
    testWidgets('renders public profile resolved by @username with Message & Share actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const targetUser = UserEntity(
        id: 'usr-target',
        phoneNumber: '+91 ••••••9999',
        username: 'sujeet',
        displayName: 'Sujeet Kumar',
        bio: 'Open source contributor & local neighborhood organizer',
        locality: 'Indiranagar',
        city: 'Bengaluru',
        onboardingCompleted: true,
      );

      final mockRepo = MockSearchAuthRepository(usernameUser: targetUser);

      final fakeStorage = FakeSecureStorageService();
      final authController = AuthController(
        authRepository: mockRepo,
        secureStorage: fakeStorage,
      )..state = const AuthAuthenticated(
          UserEntity(
            id: 'usr-viewer',
            phoneNumber: '+91 ••••••1111',
            displayName: 'Viewer',
          ),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepo),
            authControllerProvider.overrideWith((ref) => authController),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PublicProfileScreen(username: 'sujeet'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@sujeet'), findsWidgets);
      expect(find.text('Sujeet Kumar'), findsOneWidget);
      expect(
        find.text('Open source contributor & local neighborhood organizer'),
        findsOneWidget,
      );
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Privacy check: Viewer must NOT see the target user's phone number
      expect(find.textContaining('9999'), findsNothing);
    });
  });

  group('Messaging Participant Display Tests', () {
    testWidgets('displays displayName and @handle in conversation list tile',
        (tester) async {
      final convWithTime = ConversationEntity(
        id: 'conv-1',
        participant: const ConversationParticipantProfile(
          id: 'usr-99',
          displayName: 'Sujeet Kumar',
          username: 'sujeet',
          locality: 'Indiranagar',
          city: 'Bengaluru',
        ),
        lastMessageAt: DateTime(2026, 9, 28, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ConversationListTile(
              conversation: convWithTime,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sujeet Kumar'), findsOneWidget);
      expect(find.text('@sujeet'), findsOneWidget);
    });
  });

  group('Username Client Validation & Rules Tests', () {
    test('validates alphanumeric characters and underscores', () {
      final validRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

      expect(validRegex.hasMatch('sujeet'), isTrue);
      expect(validRegex.hasMatch('sujeet123'), isTrue);
      expect(validRegex.hasMatch('sujeet_kumar'), isTrue);
      expect(validRegex.hasMatch('_sujeet_'), isTrue);

      // Invalid
      expect(validRegex.hasMatch('su'), isFalse); // Too short
      expect(validRegex.hasMatch('a' * 31), isFalse); // Too long
      expect(validRegex.hasMatch('sujeet kumar'), isFalse); // Space
      expect(validRegex.hasMatch('sujeet.kumar'), isFalse); // Period
      expect(validRegex.hasMatch('sujeet-kumar'), isFalse); // Hyphen
      expect(validRegex.hasMatch('sujeet@'), isFalse); // At sign
    });

    test('UsernameAvailabilityResult correctly parses JSON states', () {
      final available = UsernameAvailabilityResult.fromJson({
        'username': 'sujeet',
        'available': true,
      });
      expect(available.username, equals('sujeet'));
      expect(available.available, isTrue);

      final unavailable = UsernameAvailabilityResult.fromJson({
        'username': 'sujeet',
        'available': false,
        'message': 'This username is already taken.',
      });
      expect(unavailable.available, isFalse);
      expect(unavailable.message, contains('already taken'));
    });
  });

  group('Deep-link and Public Profile Routing Tests', () {
    test('AppRoutes defines canonical Instagram-style @username route', () {
      expect(AppRoutes.publicProfile, equals('/@:username'));
    });
  });
}
