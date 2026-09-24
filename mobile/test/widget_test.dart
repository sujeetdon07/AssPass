import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aaspaas/core/routing/app_router.dart';
import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/core/theme/theme_mode_controller.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/communities/data/models/communities_page_model.dart';
import 'package:aaspaas/features/communities/data/repositories/communities_repository.dart';
import 'package:aaspaas/features/shell/presentation/screens/app_shell_screen.dart';
import 'package:aaspaas/main.dart';

class _TestAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _TestAuthController()
      : super(
          const AuthAuthenticated(
            UserEntity(
              id: 'usr-test-123',
              phoneNumber: '+919876543210',
              displayName: 'Aaspaas Neighbor',
              locality: 'Koramangala',
              city: 'Bengaluru',
              onboardingCompleted: true,
            ),
          ),
        );

  @override
  void updateUser(UserEntity user) {
    state = AuthAuthenticated(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFeedRepository extends Fake implements FeedRepository {
  @override
  Future<FeedPageModel> getFeed({
    String? cursor,
    int limit = 20,
    String? category,
    String scope = 'local',
  }) async {
    return const FeedPageModel(
      posts: [],
      hasMore: false,
      scope: 'local',
    );
  }
}

class _FakeCommunitiesRepository extends Fake implements CommunitiesRepository {
  @override
  Future<CommunitiesPageModel> getCommunities({
    String? cursor,
    int limit = 20,
    String? category,
    String? search,
    String scope = 'all',
    bool? joinedOnly,
    String? locality,
    String? city,
  }) async {
    return const CommunitiesPageModel(
      communities: [],
      hasMore: false,
    );
  }
}

void main() {
  setUpAll(() async {
    dotenv.testLoad(
      fileInput: '''
API_BASE_URL=http://localhost:3000/api/v1
ENVIRONMENT=development
''',
    );
    SharedPreferences.setMockInitialValues({});
  });

  group('Aaspaas App Shell & Startup', () {
    testWidgets('app launches without crashing and renders AppShellScreen',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
            communitiesRepositoryProvider
                .overrideWithValue(_FakeCommunitiesRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AaspaasApp), findsOneWidget);
      expect(find.byType(AppShellScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('top header renders Aaspaas brand, locality pill, and icons',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Brand title
      expect(find.text('Aaspaas'), findsOneWidget);
      // Locality chip
      expect(find.text('Koramangala, Bengaluru'), findsOneWidget);
      // Notifications action
      expect(find.byIcon(AppIcons.notificationsOutline), findsWidgets);
    });

    testWidgets('bottom navigation renders all five destinations',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 5 destinations in NavigationBar
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Marketplace'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('navigates between bottom navigation tabs smoothly',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
            communitiesRepositoryProvider
                .overrideWithValue(_FakeCommunitiesRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on Home tab: Check category chips & composer prompt
      expect(find.text('All Updates'), findsOneWidget);

      // Tap Nearby tab
      await tester.tap(find.text('Nearby'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nearby Discovery'),
        findsOneWidget,
      );

      // Tap Communities tab
      await tester.tap(find.text('Communities'));
      await tester.pumpAndSettle();
      expect(
        find.text('In My Area'),
        findsOneWidget,
      );

      // Tap Marketplace tab
      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Search furniture'),
        findsOneWidget,
      );

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Preview Profile'), findsOneWidget);
    });

    testWidgets('toggling theme mode on Profile tab updates theme state',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _TestAuthController()),
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              capturedRef = ref;
              return const AaspaasApp();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Tap 'Dark' chip
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(themeModeProvider), ThemeMode.dark);

      // Tap 'Light' chip
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(themeModeProvider), ThemeMode.light);
    });
  });

  group('Preserved Phase 0 Foundation Route', () {
    testWidgets('/foundation route is still accessible', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      router.go('/foundation');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your Local World, In One App.'), findsOneWidget);
      expect(find.text('Environment: development'), findsOneWidget);
    });
  });
}
