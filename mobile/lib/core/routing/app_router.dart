import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/phone_input_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/foundation/presentation/screens/foundation_screen.dart';
import '../../features/onboarding/presentation/screens/completion_screen.dart';
import '../../features/onboarding/presentation/screens/locality_setup_screen.dart';
import '../../features/onboarding/presentation/screens/profile_setup_screen.dart';
import '../../features/shell/presentation/screens/app_shell_screen.dart';
import '../../features/shell/presentation/screens/communities_screen.dart';
import '../../features/shell/presentation/screens/home_screen.dart';
import '../../features/shell/presentation/screens/nearby_screen.dart';
import '../../features/shell/presentation/screens/profile_screen.dart';
import '../../features/shell/presentation/screens/edit_profile_screen.dart';
import '../../features/feed/domain/entities/post_entity.dart';
import '../../features/feed/presentation/screens/create_post_screen.dart';
import '../../features/feed/presentation/screens/edit_post_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/communities/domain/entities/community_entity.dart';
import '../../features/communities/presentation/screens/community_detail_screen.dart';
import '../../features/communities/presentation/screens/create_community_screen.dart';
import '../../features/communities/presentation/screens/edit_community_screen.dart';
import '../../features/communities/presentation/screens/community_members_screen.dart';
import '../../features/communities/presentation/screens/community_search_screen.dart';
import '../../features/marketplace/domain/entities/marketplace_listing_entity.dart';
import '../../features/marketplace/presentation/screens/marketplace_screen.dart';
import '../../features/marketplace/presentation/screens/create_listing_screen.dart';
import '../../features/marketplace/presentation/screens/edit_listing_screen.dart';
import '../../features/marketplace/presentation/screens/listing_detail_screen.dart';
import '../../features/marketplace/presentation/screens/my_listings_screen.dart';
import '../../features/marketplace/presentation/screens/my_favorites_screen.dart';
import '../../features/businesses/domain/entities/business_entity.dart';
import '../../features/businesses/presentation/screens/businesses_screen.dart';
import '../../features/businesses/presentation/screens/business_detail_screen.dart';
import '../../features/businesses/presentation/screens/create_business_screen.dart';
import '../../features/businesses/presentation/screens/edit_business_screen.dart';
import '../../features/businesses/presentation/screens/my_businesses_screen.dart';
import '../../features/services/domain/entities/service_listing_entity.dart';
import '../../features/services/presentation/screens/services_screen.dart';
import '../../features/services/presentation/screens/service_detail_screen.dart';
import '../../features/services/presentation/screens/create_service_screen.dart';
import '../../features/services/presentation/screens/edit_service_screen.dart';
import '../../features/services/presentation/screens/my_services_screen.dart';
import '../../features/messaging/presentation/screens/conversations_screen.dart';
import '../../features/messaging/presentation/screens/conversation_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/notifications/presentation/screens/notification_settings_screen.dart';
import '../../features/safety/presentation/screens/blocked_users_screen.dart';
import '../../features/safety/presentation/screens/report_history_screen.dart';
import '../../features/events/domain/entities/event_entity.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/events/presentation/screens/event_detail_screen.dart';
import '../../features/events/presentation/screens/create_event_screen.dart';
import '../../features/events/presentation/screens/edit_event_screen.dart';

/// Centralized route paths for Aaspaas.
class AppRoutes {
  AppRoutes._();

  // Root
  static const String root = '/';

  // Auth Routes
  static const String welcome = '/welcome';
  static const String phone = '/auth/phone';
  static const String otp = '/auth/otp';

  // Onboarding Routes
  static const String profileSetup = '/onboarding/profile';
  static const String localitySetup = '/onboarding/locality';
  static const String onboardingComplete = '/onboarding/complete';

  // Authenticated Shell Routes
  static const String home = '/home';
  static const String nearby = '/nearby';
  static const String communities = '/communities';
  static const String marketplace = '/marketplace';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';

  // Feed Flow Routes
  static const String createPost = '/feed/create';
  static const String postDetail = '/feed/posts/:id';
  static const String editPost = '/feed/posts/:id/edit';

  // Communities Flow Routes
  static const String communityDetail = '/communities/:id';
  static const String createCommunity = '/communities/create';
  static const String editCommunity = '/communities/:id/edit';
  static const String communityMembers = '/communities/:id/members';
  static const String communitySearch = '/communities/search';

  // Marketplace Flow Routes
  static const String createListing = '/marketplace/create';
  static const String myListings = '/marketplace/my-listings';
  static const String marketplaceFavorites = '/marketplace/favorites';
  static const String listingDetail = '/marketplace/listings/:id';
  static const String editListing = '/marketplace/listings/:id/edit';

  // Businesses Flow Routes
  static const String businesses = '/businesses';
  static const String createBusiness = '/businesses/create';
  static const String myBusinesses = '/businesses/my-businesses';
  static const String businessDetail = '/businesses/:id';
  static const String editBusiness = '/businesses/:id/edit';

  // Services Flow Routes
  static const String services = '/services';
  static const String createService = '/services/create';
  static const String myServices = '/services/my-services';
  static const String serviceDetail = '/services/:id';
  static const String editService = '/services/:id/edit';

  // Messaging Flow Routes
  static const String messages = '/messages';
  static const String conversation = '/messages/:id';

  // Notifications Flow Routes
  static const String notifications = '/notifications';
  static const String notificationSettings = '/settings/notifications';

  // Trust & Safety Flow Routes
  static const String blockedUsers = '/settings/blocked-users';
  static const String reportHistory = '/settings/report-history';

  // Events Flow Routes
  static const String events = '/events';
  static const String eventDetail = '/events/:id';
  static const String createEvent = '/events/create';
  static const String editEvent = '/events/:id/edit';

  /// Development foundation screen (preserved from Phase 0)
  static const String foundation = '/foundation';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _rootNavigatorKey = rootNavigatorKey;

final homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
final nearbyNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'nearbyBranch');
final communitiesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'communitiesBranch');
final marketplaceNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'marketplaceBranch');
final profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileBranch');

final shellBranchNavigatorKeys = <GlobalKey<NavigatorState>>[
  homeNavigatorKey,
  nearbyNavigatorKey,
  communitiesNavigatorKey,
  marketplaceNavigatorKey,
  profileNavigatorKey,
];

/// Listenable adapter to trigger GoRouter re-evaluations on AuthState changes.
class _AuthStateNotifierListenable extends ChangeNotifier {
  _AuthStateNotifierListenable(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }
}

/// GoRouter configuration provider for Aaspaas.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthStateNotifierListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: false,
    initialLocation: AppRoutes.welcome,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Always allow development foundation screen
      if (location == AppRoutes.foundation) {
        return null;
      }

      final isAuthRoute =
          location == AppRoutes.welcome || location.startsWith('/auth');

      final isOnboardingRoute = location.startsWith('/onboarding');

      // 1. Initial loading: do not flash home screen before session check completes
      if (authState is AuthInitial) {
        if (!isAuthRoute) {
          return AppRoutes.welcome;
        }
        return null;
      }

      // 2. Unauthenticated: must be on welcome or auth screens
      if (authState is AuthUnauthenticated || authState is AuthError) {
        if (!isAuthRoute) {
          return AppRoutes.welcome;
        }
        return null;
      }

      // 3. Onboarding Required: user must complete onboarding steps
      if (authState is AuthOnboardingRequired) {
        if (!isOnboardingRoute) {
          return AppRoutes.profileSetup;
        }
        return null;
      }

      // 4. Authenticated & Onboarded: cannot visit auth or onboarding screens
      if (authState is AuthAuthenticated) {
        if (isAuthRoute ||
            (isOnboardingRoute && location != AppRoutes.onboardingComplete)) {
          return AppRoutes.home;
        }
        return null;
      }

      return null;
    },
    routes: [
      // Root redirect to /welcome
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) => AppRoutes.welcome,
      ),

      // ── Auth Flow Routes ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.welcome,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.phone,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PhoneInputScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            phoneNumber: extra?['phoneNumber'] as String? ?? '',
            maskedPhoneNumber:
                extra?['maskedPhoneNumber'] as String? ?? 'your number',
            initialDevOtp: extra?['devOtp'] as String?,
            cooldownSeconds: extra?['cooldownSeconds'] as int? ?? 60,
          );
        },
      ),

      // ── Onboarding Flow Routes ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profileSetup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.localitySetup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LocalitySetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingComplete,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CompletionScreen(),
      ),

      // ── Authenticated 5-Tab App Shell ─────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScreen(
            navigationShell: navigationShell,
            branchNavigatorKeys: shellBranchNavigatorKeys,
          );
        },
        branches: [
          // Branch 0: Home
          StatefulShellBranch(
            navigatorKey: homeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Nearby
          StatefulShellBranch(
            navigatorKey: nearbyNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.nearby,
                builder: (context, state) => const NearbyScreen(),
              ),
            ],
          ),

          // Branch 2: Communities
          StatefulShellBranch(
            navigatorKey: communitiesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.communities,
                builder: (context, state) => const CommunitiesScreen(),
              ),
            ],
          ),

          // Branch 3: Marketplace
          StatefulShellBranch(
            navigatorKey: marketplaceNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.marketplace,
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),

          // Branch 4: Profile
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Development foundation screen preserved from Phase 0
      GoRoute(
        path: AppRoutes.foundation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FoundationScreen(),
      ),

      // ── Feed Flow Routes ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createPost,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreatePostScreen(
            communityId: extra?['communityId'] as String?,
            communityName: extra?['communityName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PostDetailScreen(postId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editPost,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final post = state.extra as PostEntity;
          return EditPostScreen(post: post);
        },
      ),

      // ── Communities Flow Routes ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createCommunity,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateCommunityScreen(),
      ),
      GoRoute(
        path: AppRoutes.communitySearch,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CommunitySearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.communityDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CommunityDetailScreen(communityId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editCommunity,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final community = state.extra as CommunityEntity;
          return EditCommunityScreen(community: community);
        },
      ),
      GoRoute(
        path: AppRoutes.communityMembers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CommunityMembersScreen(communityId: id);
        },
      ),

      // ── Marketplace Flow Routes ──────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createListing,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateListingScreen(),
      ),
      GoRoute(
        path: AppRoutes.myListings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.marketplaceFavorites,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyFavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.listingDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ListingDetailScreen(listingId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editListing,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final listing = state.extra as MarketplaceListingEntity;
          return EditListingScreen(listing: listing);
        },
      ),

      // ── Businesses Flow Routes ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.businesses,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BusinessesScreen(),
      ),
      GoRoute(
        path: AppRoutes.createBusiness,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateBusinessScreen(),
      ),
      GoRoute(
        path: AppRoutes.myBusinesses,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyBusinessesScreen(),
      ),
      GoRoute(
        path: AppRoutes.businessDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return BusinessDetailScreen(businessId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editBusiness,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final business = state.extra as BusinessEntity;
          return EditBusinessScreen(business: business);
        },
      ),

      // ── Services Flow Routes ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.services,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: AppRoutes.createService,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.myServices,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyServicesScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ServiceDetailScreen(serviceId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.editService,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final service = state.extra as ServiceListingEntity;
          return EditServiceScreen(service: service);
        },
      ),
      GoRoute(
        path: AppRoutes.messages,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.conversation,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ConversationScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.blockedUsers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportHistory,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportHistoryScreen(),
      ),

      // ── Events Flow Routes ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.events,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: AppRoutes.createEvent,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final communityId = state.extra as String?;
          return CreateEventScreen(communityId: communityId);
        },
      ),
      GoRoute(
        path: AppRoutes.eventDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final event = state.extra as EventEntity?;
          return EventDetailScreen(eventId: id, initialEvent: event);
        },
      ),
      GoRoute(
        path: AppRoutes.editEvent,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final event = state.extra as EventEntity;
          return EditEventScreen(event: event);
        },
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
    ],
  );
});
