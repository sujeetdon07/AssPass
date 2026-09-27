import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aaspaas/core/routing/app_router.dart';
import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/features/auth/application/auth_controller.dart';
import 'package:aaspaas/features/auth/application/auth_state.dart';
import 'package:aaspaas/features/auth/domain/entities/user_entity.dart';
import 'package:aaspaas/features/feed/data/models/feed_page_model.dart';
import 'package:aaspaas/features/feed/data/repositories/feed_repository.dart';
import 'package:aaspaas/features/communities/data/models/communities_page_model.dart';
import 'package:aaspaas/features/communities/data/repositories/communities_repository.dart';
import 'package:aaspaas/features/events/data/models/events_page_model.dart';
import 'package:aaspaas/features/events/data/repositories/events_repository.dart';
import 'package:aaspaas/features/shell/presentation/screens/app_shell_screen.dart';
import 'package:aaspaas/features/shell/presentation/screens/home_screen.dart';
import 'package:aaspaas/shared/widgets/avatars/app_avatar.dart';
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

class _FakeEventsRepository extends Fake implements EventsRepository {
  @override
  Future<EventsPageModel> getEvents({
    String? cursor,
    int limit = 20,
    String? category,
    String? locality,
    String? city,
    String? communityId,
    String timeframe = 'upcoming',
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    return const EventsPageModel(
      events: [],
      hasMore: false,
    );
  }
}

Widget _buildTestApp(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authControllerProvider.overrideWith((ref) => _TestAuthController()),
      feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
      communitiesRepositoryProvider
          .overrideWithValue(_FakeCommunitiesRepository()),
      eventsRepositoryProvider.overrideWithValue(_FakeEventsRepository()),
    ],
    child: const AaspaasApp(),
  );
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

  group('Global Android Back Navigation Tests', () {
    testWidgets('Home root -> Back -> allows app exit (handlePopRoute returns false)',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Back pressed on Home root -> Should allow OS exit
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isFalse, reason: 'Home root must allow app exit');
    });

    testWidgets('Nearby root -> Back -> Home -> Back -> Exit',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Navigate to Nearby tab
      await tester.tap(find.text('Nearby'));
      await tester.pumpAndSettle();
      expect(find.text('Nearby Discovery'), findsOneWidget);

      // First Back: Must return to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Second Back from Home: Must allow app exit
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isFalse);
    });

    testWidgets('Communities root -> Back -> Home -> Back -> Exit',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Navigate to Communities tab
      await tester.tap(find.text('Communities'));
      await tester.pumpAndSettle();
      expect(find.text('In My Area'), findsOneWidget);

      // First Back: Must return to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Second Back: Must allow app exit
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isFalse);
    });

    testWidgets('Marketplace root -> Back -> Home -> Back -> Exit',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Navigate to Marketplace tab
      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Search furniture'), findsOneWidget);

      // First Back: Must return to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Second Back: Must allow app exit
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isFalse);
    });

    testWidgets('Profile root -> Back -> Home -> Back -> Exit',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Navigate to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy & Safety'), findsOneWidget);

      // First Back: Must return to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Second Back: Must allow app exit
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isFalse);
    });

    testWidgets('Top-right Profile avatar button opens Profile -> Back -> Home',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Tap profile avatar in top-right corner of AppBar
      final avatarFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AppAvatar),
      );
      expect(avatarFinder, findsOneWidget);
      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Safety'), findsOneWidget);

      // Press Back: Must return to Home
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Next Back from Home: Must allow app exit
      final exitHandled = await tester.binding.handlePopRoute();
      expect(exitHandled, isFalse);
    });

    testWidgets('Child route on root navigator -> Back -> returns to parent',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // From Home, open Feed create post
      final context = tester.element(find.byType(HomeScreen));
      context.push(AppRoutes.createPost);
      await tester.pumpAndSettle();

      // Feed create post screen is visible
      expect(find.text('Create Post'), findsWidgets);

      // First Back: Pops back to HomeScreen (parent)
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Second Back: Exits app
      final exitHandled = await tester.binding.handlePopRoute();
      expect(exitHandled, isFalse);
    });

    testWidgets('Modal dialog / bottom sheet consumes Back before screen navigation',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Navigate to Communities tab
      await tester.tap(find.text('Communities'));
      await tester.pumpAndSettle();

      // Open a bottom sheet modal
      final context = tester.element(find.byType(AppShellScreen));
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => const SizedBox(
          height: 200,
          child: Text('Test Modal Sheet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Modal Sheet'), findsOneWidget);

      // First Back: Must dismiss the modal sheet, NOT navigate to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pumpAndSettle();

      // Modal is dismissed, still on Communities
      expect(find.text('Test Modal Sheet'), findsNothing);
      expect(find.text('In My Area'), findsOneWidget);

      // Second Back: Now switches to Home
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Third Back: Exits app
      final handledThird = await tester.binding.handlePopRoute();
      expect(handledThird, isFalse);
    });

    testWidgets('Events opened via push -> Back -> returns to Home',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Open events screen via context.push
      final context = tester.element(find.byType(HomeScreen));
      context.push(AppRoutes.events);
      await tester.pumpAndSettle();

      expect(find.text('Local Events'), findsOneWidget);

      // Back press -> Pops back to Home
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Next Back -> App exit
      final exitHandled = await tester.binding.handlePopRoute();
      expect(exitHandled, isFalse);
    });

    testWidgets('Events opened directly via context.go -> Back -> navigates to Home',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Direct navigation to events (canPop is false)
      final context = tester.element(find.byType(HomeScreen));
      context.go(AppRoutes.events);
      await tester.pumpAndSettle();

      expect(find.text('Local Events'), findsOneWidget);

      // Back press -> Gracefully navigates to Home
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      // Next Back -> App exit
      final exitHandled = await tester.binding.handlePopRoute();
      expect(exitHandled, isFalse);
    });

    testWidgets('Community details opened directly -> Back -> navigates to Communities',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_buildTestApp(prefs));
      await tester.pumpAndSettle();

      // Direct navigation to a community detail screen (simulating deep link)
      final context = tester.element(find.byType(HomeScreen));
      context.go('/communities/test-comm-123');
      await tester.pumpAndSettle();

      // Back press -> Gracefully unwinds to Communities
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('In My Area'), findsOneWidget);

      // Next Back -> Switches to Home
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('All Updates'), findsOneWidget);

      // Next Back -> App exit
      final exitHandled = await tester.binding.handlePopRoute();
      expect(exitHandled, isFalse);
    });
  });
}
