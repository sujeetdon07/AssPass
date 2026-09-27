import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/features/marketplace/application/favorites_controller.dart';
import 'package:aaspaas/features/marketplace/data/models/marketplace_listing_model.dart';
import 'package:aaspaas/features/marketplace/data/repositories/marketplace_repository.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_category.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_condition.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_listing_entity.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_status.dart';
import 'package:aaspaas/features/marketplace/domain/entities/seller_profile_entity.dart';
import 'package:aaspaas/features/marketplace/presentation/screens/listing_detail_screen.dart';
import 'package:aaspaas/features/marketplace/presentation/screens/my_favorites_screen.dart';
import 'package:aaspaas/features/marketplace/presentation/screens/my_listings_screen.dart';
import 'package:aaspaas/features/marketplace/presentation/widgets/listing_card.dart';
import 'package:aaspaas/features/marketplace/presentation/widgets/listing_status_chip.dart';

class _FakeMarketplaceRepository extends Fake
    implements MarketplaceRepository {
  List<MarketplaceListingEntity> favoriteItems = [];
  List<MarketplaceListingEntity> myListingsItems = [];
  MarketplaceListingEntity? singleListing;
  bool shouldThrow = false;
  int unfavoriteCalls = 0;
  int updateStatusCalls = 0;
  String? lastUpdatedStatus;

  @override
  Future<MarketplaceListingPageModel> getFavorites({
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Network error fetching favorites');
    return MarketplaceListingPageModel(
      items: favoriteItems,
      hasMore: false,
    );
  }

  @override
  Future<MarketplaceListingPageModel> getMyListings({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Network error fetching my listings');
    final filtered = status == null
        ? myListingsItems
        : myListingsItems.where((l) => l.status.value == status).toList();
    return MarketplaceListingPageModel(
      items: filtered,
      hasMore: false,
    );
  }

  @override
  Future<MarketplaceListingEntity> getListingById(String id) async {
    if (shouldThrow) throw Exception('Listing not found');
    if (singleListing != null) return singleListing!;
    return _createTestListing(id: id);
  }

  @override
  Future<void> unfavoriteListing(String id) async {
    unfavoriteCalls++;
    if (shouldThrow) throw Exception('Failed to unfavorite');
  }

  @override
  Future<MarketplaceListingEntity> updateListingStatus(
    String id,
    String status,
  ) async {
    updateStatusCalls++;
    lastUpdatedStatus = status;
    final updated = (singleListing ?? _createTestListing(id: id)).copyWith(
      status: MarketplaceListingStatus.fromString(status),
    );
    singleListing = updated;
    return updated;
  }
}

MarketplaceListingEntity _createTestListing({
  String id = 'list-1',
  String title = 'Vintage Camera',
  double price = 4500,
  MarketplaceListingStatus status = MarketplaceListingStatus.active,
  bool isFavorited = true,
  bool isOwner = true,
}) {
  return MarketplaceListingEntity(
    id: id,
    sellerId: 'user-seller-1',
    seller: const SellerProfileEntity(
      id: 'user-seller-1',
      displayName: 'Rahul S',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    ),
    title: title,
    description: 'Classic 35mm film camera in working condition.',
    category: MarketplaceCategory.electronics,
    price: price,
    currency: 'INR',
    condition: MarketplaceCondition.good,
    status: status,
    locality: 'Indiranagar',
    city: 'Bengaluru',
    favoriteCount: 5,
    isFavorited: isFavorited,
    isOwner: isOwner,
    images: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('FavoritesController unit tests', () {
    late _FakeMarketplaceRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeMarketplaceRepository();
    });

    test('loadFavorites successfully populates state with items', () async {
      fakeRepo.favoriteItems = [
        _createTestListing(id: 'fav-1', title: 'Item 1'),
        _createTestListing(id: 'fav-2', title: 'Item 2'),
      ];

      final controller = FavoritesController(fakeRepo);
      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isLoading, false);
      expect(controller.state.listings.length, 2);
      expect(controller.state.listings.first.id, 'fav-1');
    });

    test('unfavorite immediately removes listing from state', () async {
      fakeRepo.favoriteItems = [
        _createTestListing(id: 'fav-1', title: 'Item 1'),
        _createTestListing(id: 'fav-2', title: 'Item 2'),
      ];

      final controller = FavoritesController(fakeRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await controller.unfavorite('fav-1');

      expect(controller.state.listings.length, 1);
      expect(controller.state.listings.first.id, 'fav-2');
      expect(fakeRepo.unfavoriteCalls, 1);
    });

    test('loadFavorites handles network error gracefully', () async {
      fakeRepo.shouldThrow = true;

      final controller = FavoritesController(fakeRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.listings.isEmpty, true);
    });
  });

  group('MyFavoritesScreen Widget tests', () {
    testWidgets('renders empty state when user has no favorites',
        (tester) async {
      final fakeRepo = _FakeMarketplaceRepository()..favoriteItems = [];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: MyFavoritesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Favorites'), findsOneWidget);
      expect(find.text('No Favorites Yet'), findsOneWidget);
      expect(find.text('Listings you save will appear here.'), findsOneWidget);
      expect(find.text('Browse Marketplace'), findsOneWidget);
    });

    testWidgets('renders favorite cards and unfavorites on heart tap',
        (tester) async {
      final fakeRepo = _FakeMarketplaceRepository()
        ..favoriteItems = [
          _createTestListing(id: 'fav-1', title: 'Antique Desk Clock'),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: MyFavoritesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Antique Desk Clock'), findsOneWidget);

      // Tap the favorite icon to unfavorite
      await tester.tap(find.byIcon(AppIcons.like));
      await tester.pumpAndSettle();

      // Card removed optimistically
      expect(find.text('Antique Desk Clock'), findsNothing);
      expect(find.text('No Favorites Yet'), findsOneWidget);
    });
  });

  group('ListingDetailScreen Status-Aware Owner Actions', () {
    testWidgets('ACTIVE listing: displays Edit, Mark Sold, Archive, and Delete',
        (tester) async {
      final listing = _createTestListing(
        id: 'active-item',
        status: MarketplaceListingStatus.active,
        isOwner: true,
      );
      final fakeRepo = _FakeMarketplaceRepository()..singleListing = listing;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ListingDetailScreen(listingId: 'active-item'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom bar actions for Active listing
      expect(find.text('Mark as Sold'), findsOneWidget);
      expect(find.text('Edit Listing'), findsOneWidget);
      expect(find.text('Relist as Active'), findsNothing);
      expect(find.text('Restore Listing'), findsNothing);

      // Open AppBar PopupMenu
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      expect(find.text('Edit Listing'), findsNWidgets(2)); // in bar & popup
      expect(find.text('Mark as Sold'), findsNWidgets(2)); // in bar & popup
      expect(find.text('Archive Listing'), findsOneWidget);
      expect(find.text('Delete Listing'), findsOneWidget);
      expect(find.text('Restore / Unarchive Listing'), findsNothing);

      // Tap Archive Listing -> confirmation dialog appears
      await tester.tap(find.text('Archive Listing'));
      await tester.pumpAndSettle();

      expect(find.text('Archive Listing'), findsWidgets); // title & button
      expect(
        find.text(
          'Archiving will hide this listing from the marketplace. You can restore it anytime from My Listings.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);

      // Tap Archive to confirm
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(fakeRepo.updateStatusCalls, 1);
      expect(fakeRepo.lastUpdatedStatus, 'archived');
    });

    testWidgets('SOLD listing: displays Relist as Active, Archive, and Delete',
        (tester) async {
      final listing = _createTestListing(
        id: 'sold-item',
        status: MarketplaceListingStatus.sold,
        isOwner: true,
      );
      final fakeRepo = _FakeMarketplaceRepository()..singleListing = listing;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ListingDetailScreen(listingId: 'sold-item'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom bar actions for Sold listing
      expect(find.text('Relist as Active'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Mark as Sold'), findsNothing);

      // Open AppBar PopupMenu
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Active / Relist'), findsOneWidget);
      expect(find.text('Archive Listing'), findsOneWidget);
      expect(find.text('Delete Listing'), findsOneWidget);
      expect(find.text('Restore / Unarchive Listing'), findsNothing);
    });

    testWidgets('ARCHIVED listing: displays Restore and Delete',
        (tester) async {
      final listing = _createTestListing(
        id: 'archived-item',
        status: MarketplaceListingStatus.archived,
        isOwner: true,
      );
      final fakeRepo = _FakeMarketplaceRepository()..singleListing = listing;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ListingDetailScreen(listingId: 'archived-item'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bottom bar actions for Archived listing
      expect(find.text('Restore Listing'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Mark as Sold'), findsNothing);
      expect(find.text('Edit Listing'), findsNothing);

      // Open AppBar PopupMenu
      await tester.tap(find.byIcon(AppIcons.more));
      await tester.pumpAndSettle();

      expect(find.text('Restore / Unarchive Listing'), findsOneWidget);
      expect(find.text('Delete Listing'), findsOneWidget);
      expect(find.text('Archive Listing'), findsNothing);
      expect(find.text('Mark as Sold'), findsNothing);

      // Tap Restore / Unarchive Listing -> confirmation dialog appears
      await tester.tap(find.text('Restore / Unarchive Listing'));
      await tester.pumpAndSettle();

      expect(find.text('Restore Listing'), findsWidgets);
      expect(
        find.text(
          'Restoring will make this listing visible in the marketplace again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(fakeRepo.updateStatusCalls, 1);
      expect(fakeRepo.lastUpdatedStatus, 'active');
    });
  });

  group('MyListingsScreen and ListingCard status badge tests', () {
    testWidgets('MyListingsScreen renders status tabs and listing cards',
        (tester) async {
      final fakeRepo = _FakeMarketplaceRepository()
        ..myListingsItems = [
          _createTestListing(
            id: 'item-act',
            title: 'Active Sofa',
            status: MarketplaceListingStatus.active,
          ),
          _createTestListing(
            id: 'item-sold',
            title: 'Sold Bicycle',
            status: MarketplaceListingStatus.sold,
          ),
          _createTestListing(
            id: 'item-arc',
            title: 'Archived TV',
            status: MarketplaceListingStatus.archived,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketplaceRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: MyListingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.widgetWithText(Tab, 'All'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Active'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Sold'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Archived'), findsOneWidget);

      // In All tab, all 3 are visible
      expect(find.text('Active Sofa'), findsOneWidget);
      expect(find.text('Sold Bicycle'), findsOneWidget);
      expect(find.text('Archived TV'), findsOneWidget);

      // Status chips are displayed on cards
      expect(find.widgetWithText(ListingStatusChip, 'Active'), findsOneWidget);
      expect(find.widgetWithText(ListingStatusChip, 'Sold'), findsOneWidget);
      expect(find.widgetWithText(ListingStatusChip, 'Archived'), findsOneWidget);
    });

    testWidgets('ListingCard showStatusAlways displays active chip',
        (tester) async {
      final activeListing = _createTestListing(
        id: 'card-1',
        title: 'Active Laptop',
        status: MarketplaceListingStatus.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: ListingCard(
                listing: activeListing,
                showStatusAlways: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.widgetWithText(ListingStatusChip, 'Active'), findsOneWidget);
    });
  });
}
