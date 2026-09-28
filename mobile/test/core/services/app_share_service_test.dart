import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/core/config/app_config.dart';
import 'package:aaspaas/core/services/app_share_service.dart';
import 'package:aaspaas/features/feed/domain/entities/post_entity.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_listing_entity.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_category.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_condition.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_status.dart';
import 'package:aaspaas/features/marketplace/domain/entities/seller_profile_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_entity.dart';
import 'package:aaspaas/features/events/domain/entities/event_category.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_entity.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_category.dart';
import 'package:aaspaas/features/businesses/domain/entities/operating_hours.dart';
import 'package:aaspaas/features/services/domain/entities/service_listing_entity.dart';
import 'package:aaspaas/features/services/domain/entities/service_category.dart';
import 'package:aaspaas/features/communities/domain/entities/community_entity.dart';
import 'package:aaspaas/features/communities/domain/entities/community_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShareService Payload Builders', () {
    test('buildPostPayload constructs correct title, text snippet, and deep-link URL', () {
      final post = PostEntity(
        id: 'post-123',
        authorId: 'user-1',
        authorName: 'Sujeet Kumar',
        content: 'BESCOM scheduled power cut tomorrow from 10 AM to 2 PM.',
        category: PostCategory.alert,
        locality: '5th Block, Koramangala',
        city: 'Bengaluru',
        likeCount: 5,
        commentCount: 2,
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildPostPayload(post);

      expect(payload.title, 'Post by Sujeet Kumar on Aaspaas');
      expect(payload.contentType, ShareContentType.post);
      expect(payload.url, '${AppConfig.shareBaseUrl}/feed/posts/post-123');
      expect(payload.text, contains('Check out this post on Aaspaas:'));
      expect(payload.text, contains('BESCOM scheduled power cut'));
      expect(payload.formattedText, contains('Check out this post on Aaspaas:'));
      expect(payload.formattedText, contains('${AppConfig.shareBaseUrl}/feed/posts/post-123'));
    });

    test('buildPostPayload handles empty content gracefully without throwing', () {
      final post = PostEntity(
        id: 'post-empty',
        authorId: 'user-2',
        authorName: 'Aarav Patel',
        content: '',
        category: PostCategory.general,
        locality: 'Indiranagar',
        city: 'Bengaluru',
        likeCount: 0,
        commentCount: 0,
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildPostPayload(post);

      expect(payload.title, 'Post by Aarav Patel on Aaspaas');
      expect(payload.text, contains('A local update from Aarav Patel'));
      expect(payload.url, '${AppConfig.shareBaseUrl}/feed/posts/post-empty');
    });

    test('buildPostPayload truncates very long content for clean preview', () {
      final post = PostEntity(
        id: 'post-long',
        authorId: 'user-3',
        authorName: 'Sneha Rao',
        content: 'A' * 200,
        category: PostCategory.recommendation,
        locality: 'HSR Layout',
        city: 'Bengaluru',
        likeCount: 0,
        commentCount: 0,
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildPostPayload(post);
      expect(payload.text, contains('...'));
      expect(payload.text.length, lessThan(200));
    });

    test('buildMarketplacePayload formats INR currency and canonical listing link', () {
      final listing = MarketplaceListingEntity(
        id: 'listing-456',
        sellerId: 'user-1',
        seller: const SellerProfileEntity(
          id: 'user-1',
          displayName: 'Ramesh',
          locality: 'Koramangala',
          city: 'Bengaluru',
        ),
        title: 'Ergonomic Office Chair',
        description: 'Barely used Herman Miller style chair in mint condition.',
        price: 3500.0,
        category: MarketplaceCategory.furniture,
        condition: MarketplaceCondition.likeNew,
        status: MarketplaceListingStatus.active,
        images: const [],
        locality: 'Koramangala',
        city: 'Bengaluru',
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildMarketplacePayload(listing);

      expect(payload.title, 'Ergonomic Office Chair on Aaspaas Marketplace');
      expect(payload.contentType, ShareContentType.marketplace);
      expect(payload.url, '${AppConfig.shareBaseUrl}/marketplace/listings/listing-456');
      expect(payload.text, contains('Check out this listing on Aaspaas:'));
      expect(payload.text, contains('Ergonomic Office Chair'));
      expect(payload.text, contains('₹3,500'));
    });

    test('buildEventPayload formats event date, title, and link', () {
      final event = EventEntity(
        id: 'event-789',
        creatorId: 'user-organizer',
        creator: const EventOrganizerEntity(
          id: 'user-organizer',
          displayName: 'Green Club',
        ),
        title: 'Neighborhood Tree Planting Drive',
        description: 'Planting 100 saplings across 3rd block park.',
        category: EventCategory.volunteering,
        status: 'active',
        startAt: DateTime(2026, 10, 5, 9, 30),
        endAt: DateTime(2026, 10, 5, 12, 0),
        timezone: 'Asia/Kolkata',
        venue: '3rd Block Park',
        address: '100ft road, Koramangala',
        locality: 'Koramangala',
        city: 'Bengaluru',
        participantCount: 15,
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildEventPayload(event);

      expect(payload.title, 'Neighborhood Tree Planting Drive on Aaspaas');
      expect(payload.contentType, ShareContentType.event);
      expect(payload.url, '${AppConfig.shareBaseUrl}/events/event-789');
      expect(payload.text, contains('Neighborhood Tree Planting Drive'));
      expect(payload.text, contains('Oct 5'));
      expect(payload.text, contains('9:30 AM'));
    });

    test('buildBusinessPayload formats local business name and category', () {
      final business = BusinessEntity(
        id: 'biz-101',
        ownerId: 'owner-1',
        owner: const BusinessOwnerEntity(id: 'owner-1', displayName: 'Priya'),
        name: 'Koramangala Artisan Bakery',
        slug: 'koramangala-artisan-bakery',
        description: 'Fresh sourdough breads, bagels, and pastries daily.',
        category: BusinessCategory.foodDining,
        status: BusinessStatus.active,
        verificationStatus: BusinessVerificationStatus.verified,
        operatingStatus: const OperatingStatusEntity(
          isOpen: true,
          status: 'open_now',
          statusText: 'Open Now',
        ),
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildBusinessPayload(business);

      expect(payload.title, 'Koramangala Artisan Bakery on Aaspaas');
      expect(payload.contentType, ShareContentType.business);
      expect(payload.url, '${AppConfig.shareBaseUrl}/businesses/biz-101');
      expect(payload.text, contains('Check out this local business on Aaspaas:'));
      expect(payload.text, contains('Koramangala Artisan Bakery'));
    });

    test('buildServicePayload formats starting price and title', () {
      final service = ServiceListingEntity(
        id: 'srv-202',
        providerId: 'provider-1',
        provider: const ServiceProviderEntity(id: 'provider-1', displayName: 'Vinod'),
        title: 'Professional Home Plumbing & Leak Repair',
        description: '20+ years experienced certified plumber.',
        category: ServiceCategory.plumber,
        pricingModel: PricingModel.hourly,
        startingPrice: 350.0,
        status: ServiceStatus.active,
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildServicePayload(service);

      expect(payload.title, 'Professional Home Plumbing & Leak Repair on Aaspaas');
      expect(payload.contentType, ShareContentType.service);
      expect(payload.url, '${AppConfig.shareBaseUrl}/services/srv-202');
      expect(payload.text, contains('Starting at ₹350'));
    });

    test('buildCommunityPayload formats community name and description', () {
      final community = CommunityEntity(
        id: 'comm-303',
        name: 'Koramangala Runners & Fitness Club',
        slug: 'koramangala-runners',
        description: 'Morning jogs, marathon prep, and weekend cycling groups.',
        category: CommunityCategory.sports,
        locality: 'Koramangala',
        city: 'Bengaluru',
        memberCount: 84,
        creatorId: 'creator-1',
        createdAt: DateTime(2026, 9, 28),
        updatedAt: DateTime(2026, 9, 28),
      );

      final payload = AppShareService.buildCommunityPayload(community);

      expect(payload.title, 'Koramangala Runners & Fitness Club on Aaspaas');
      expect(payload.contentType, ShareContentType.community);
      expect(payload.url, '${AppConfig.shareBaseUrl}/communities/comm-303');
      expect(payload.text, contains('Morning jogs, marathon prep'));
    });
  });

  group('AppShareService Native Channel Execution', () {
    testWidgets('invokes method channel with proper Android ACTION_SEND payload', (tester) async {
      MethodCall? capturedCall;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppShareService.channel,
        (call) async {
          capturedCall = call;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  AppShareService.share(
                    context,
                    const SharePayload(
                      title: 'Test Title',
                      text: 'Test Body',
                      url: 'https://aaspaas.app/feed/posts/123',
                      subject: 'Test Subject',
                    ),
                  );
                },
                child: const Text('Share'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(capturedCall, isNotNull);
      expect(capturedCall!.method, 'share');
      expect(capturedCall!.arguments['title'], 'Test Title');
      expect(capturedCall!.arguments['text'], contains('Test Body'));
      expect(capturedCall!.arguments['text'], contains('https://aaspaas.app/feed/posts/123'));
      expect(capturedCall!.arguments['subject'], 'Test Subject');
      expect(capturedCall!.arguments['url'], 'https://aaspaas.app/feed/posts/123');
    });

    testWidgets('gracefully handles channel errors by falling back to clipboard without crashing', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        AppShareService.channel,
        (call) async {
          throw PlatformException(code: 'UNAVAILABLE', message: 'Activity not found');
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(Scaffold));
      final result = await AppShareService.share(
        context,
        const SharePayload(
          title: 'Fallback Test',
          text: 'Fallback content',
          url: 'https://aaspaas.app/test',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Does not throw an uncaught exception, returns false, copies to clipboard, and shows snackbar
      expect(result, isFalse);
      expect(copiedText, contains('Fallback content'));
      expect(find.text('Link copied to clipboard.'), findsOneWidget);
    });

    testWidgets('empty payload returns false and warns user', (tester) async {
      bool result = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AppShareService.share(
                      context,
                      const SharePayload(
                        title: '',
                        text: '',
                        url: '',
                      ),
                    );
                  },
                  child: const Text('Share'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('Nothing to share.'), findsOneWidget);
    });
  });
}
