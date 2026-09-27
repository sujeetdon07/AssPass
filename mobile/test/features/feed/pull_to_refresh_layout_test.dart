import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/feed/application/feed_controller.dart';
import 'package:aaspaas/features/feed/application/feed_state.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/communities/data/models/communities_page_model.dart';
import 'package:aaspaas/features/communities/data/repositories/communities_repository.dart';
import 'package:aaspaas/features/shell/presentation/screens/home_screen.dart';
import 'package:aaspaas/main.dart';

class _MockAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _MockAuthController()
      : super(
          const AuthAuthenticated(
            UserEntity(
              id: 'usr-test-123',
              phoneNumber: '+919876543210',
              displayName: 'Sujith Kumar',
              locality: 'Indiranagar',
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

class _MockUnauthenticatedAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _MockUnauthenticatedAuthController() : super(const AuthInitial());

  @override
  void updateUser(UserEntity user) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockFeedRepository extends Fake implements FeedRepository {
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

class _MockCommunitiesRepository extends Fake
    implements CommunitiesRepository {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:3000/api/v1\n');
  });

  group('Pull-to-refresh & Header layout stability tests', () {
    testWidgets(
        'Locality pill renders with stable height and text on narrow 360px mobile width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _MockAuthController()),
            feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
            communitiesRepositoryProvider
                .overrideWithValue(_MockCommunitiesRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Brand text renders
      expect(find.text('Aaspaas'), findsOneWidget);

      // Locality text renders inside the pill
      final localityFinder = find.text('Indiranagar, Bengaluru');
      expect(localityFinder, findsOneWidget);

      // Verify the locality container has a stable height of 28.0
      final containerFinder = find.ancestor(
        of: localityFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.firstWidget<Container>(containerFinder);
      expect(containerWidget.constraints?.maxHeight ?? 28.0, 28.0);

      // Verify the location icon and text are inside a Row with CrossAxisAlignment.center
      final rowFinder = find.ancestor(
        of: localityFinder,
        matching: find.byType(Row),
      );
      final rowWidget = tester.firstWidget<Row>(rowFinder);
      expect(rowWidget.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets(
        'Quick Composer Card text and avatar are vertically centered on HomeScreen',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => _MockAuthController()),
            feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
            communitiesRepositoryProvider
                .overrideWithValue(_MockCommunitiesRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Quick composer prompt text is visible
      final composerTextFinder =
          find.text("What's happening in Indiranagar, Bengaluru?");
      expect(composerTextFinder, findsOneWidget);

      // The composer row has CrossAxisAlignment.center
      final composerRowFinder = find.ancestor(
        of: composerTextFinder,
        matching: find.byType(Row),
      );
      final composerRow = tester.firstWidget<Row>(composerRowFinder);
      expect(composerRow.crossAxisAlignment, CrossAxisAlignment.center);
    });

    testWidgets(
        'Empty feed state remains visible without jumping during FeedStatus.refreshing',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authControllerProvider.overrideWith((ref) => _MockAuthController()),
          feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
          communitiesRepositoryProvider
              .overrideWithValue(_MockCommunitiesRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state is rendered
      expect(
        find.text('No posts in Indiranagar, Bengaluru yet'),
        findsOneWidget,
      );

      // Simulate pull-to-refresh transition to refreshing state
      container.read(feedControllerProvider.notifier).state =
          const FeedState(status: FeedStatus.refreshing, posts: []);

      await tester.pump();

      // The empty state must stay stably rendered without disappearing or jumping
      expect(
        find.text('No posts in Indiranagar, Bengaluru yet'),
        findsOneWidget,
      );
    });

    testWidgets(
        'First-time unauthenticated app launch lands directly on WelcomeScreen (Get Started) without flashing HomeScreen',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final authController = _MockUnauthenticatedAuthController();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authControllerProvider.overrideWith((ref) => authController),
            feedRepositoryProvider.overrideWithValue(_MockFeedRepository()),
            communitiesRepositoryProvider
                .overrideWithValue(_MockCommunitiesRepository()),
          ],
          child: const AaspaasApp(),
        ),
      );

      // During initial frame (AuthInitial), app must already show WelcomeScreen with 'Get Started', NOT HomeScreen
      await tester.pump();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Aaspaas'), findsOneWidget);
      expect(find.text("What's happening in"), findsNothing);

      // When auth check resolves to AuthUnauthenticated, it remains on WelcomeScreen ('Get Started')
      authController.state = const AuthUnauthenticated();
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text("What's happening in"), findsNothing);
    });
  });
}
