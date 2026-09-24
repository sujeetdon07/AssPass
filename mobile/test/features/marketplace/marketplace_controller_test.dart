import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/marketplace/application/marketplace_controller.dart';
import 'package:aaspaas/features/marketplace/data/models/marketplace_listing_model.dart';
import 'package:aaspaas/features/marketplace/data/repositories/marketplace_repository.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_category.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_condition.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_filter.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_listing_entity.dart';
import 'package:aaspaas/features/marketplace/domain/entities/marketplace_status.dart';
import 'package:aaspaas/features/marketplace/domain/entities/seller_profile_entity.dart';

class _FakeMarketplaceRepository extends Fake implements MarketplaceRepository {
  List<MarketplaceListingEntity> returnListings = [];
  bool shouldThrow = false;
  String? nextCursor;
  bool hasMore = false;
  int favoriteCalls = 0;
  int unfavoriteCalls = 0;

  @override
  Future<MarketplaceListingPageModel> getListings({
    String? cursor,
    int limit = 20,
    String? query,
    String? category,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? locality,
    String? city,
    int? radius,
    double? latitude,
    double? longitude,
    String? sortBy,
  }) async {
    if (shouldThrow) throw Exception('Failed to load listings from network');
    return MarketplaceListingPageModel(
      items: returnListings,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<void> favoriteListing(String id) async {
    favoriteCalls++;
    if (shouldThrow) throw Exception('Failed to favorite');
  }

  @override
  Future<void> unfavoriteListing(String id) async {
    unfavoriteCalls++;
    if (shouldThrow) throw Exception('Failed to unfavorite');
  }
}

MarketplaceListingEntity _createListing({
  String id = 'list-1',
  String title = 'Bicycle for commute',
  MarketplaceCategory category = MarketplaceCategory.vehicles,
  double price = 2500,
  bool isFavorited = false,
  int favoriteCount = 3,
}) {
  return MarketplaceListingEntity(
    id: id,
    sellerId: 'seller-1',
    seller: const SellerProfileEntity(
      id: 'seller-1',
      displayName: 'Local Seller',
      locality: 'Indiranagar',
      city: 'Bengaluru',
    ),
    title: title,
    description: 'A great city bicycle in good running condition.',
    category: category,
    price: price,
    currency: 'INR',
    condition: MarketplaceCondition.good,
    status: MarketplaceListingStatus.active,
    city: 'Bengaluru',
    locality: 'Indiranagar',
    favoriteCount: favoriteCount,
    isFavorited: isFavorited,
    isOwner: false,
    images: const [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('MarketplaceController', () {
    late _FakeMarketplaceRepository fakeRepo;
    late MarketplaceController controller;

    setUp(() {
      fakeRepo = _FakeMarketplaceRepository();
    });

    test('Initial state is idle before loading', () {
      controller = MarketplaceController(fakeRepo);
      expect(controller.state.isLoading, false);
      expect(controller.state.listings, isEmpty);
    });

    test('loadListings successfully populates state', () async {
      fakeRepo.returnListings = [
        _createListing(id: 'item-1', title: 'Study Chair'),
        _createListing(id: 'item-2', title: 'Coffee Table'),
      ];
      fakeRepo.hasMore = false;

      controller = MarketplaceController(fakeRepo);
      await controller.loadListings();

      expect(controller.state.isLoading, false);
      expect(controller.state.listings.length, 2);
      expect(controller.state.listings.first.title, 'Study Chair');
      expect(controller.state.hasMore, false);
      expect(controller.state.errorMessage, isNull);
    });

    test('Handles network error gracefully with errorMessage', () async {
      fakeRepo.shouldThrow = true;

      controller = MarketplaceController(fakeRepo);
      await controller.loadListings();

      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.listings, isEmpty);
    });

    test('setCategory updates filter and triggers reload', () async {
      fakeRepo.returnListings = [
        _createListing(
          id: 'item-elec',
          category: MarketplaceCategory.electronics,
        ),
      ];

      controller = MarketplaceController(fakeRepo);
      await controller.setCategory(MarketplaceCategory.electronics);

      expect(
        controller.state.filter.category,
        MarketplaceCategory.electronics,
      );
      expect(controller.state.listings.length, 1);
    });

    test('setSearchQuery updates filter query and reloads', () async {
      fakeRepo.returnListings = [
        _createListing(id: 'item-search', title: 'Sony Headphones'),
      ];

      controller = MarketplaceController(fakeRepo);
      await controller.setSearchQuery('Headphones');

      expect(controller.state.filter.query, 'Headphones');
      expect(controller.state.listings.length, 1);
      expect(controller.state.listings.first.title, 'Sony Headphones');
    });

    test('toggleFavorite optimistically updates local item state', () async {
      fakeRepo.returnListings = [
        _createListing(
          id: 'fav-item',
          isFavorited: false,
          favoriteCount: 2,
        ),
      ];

      controller = MarketplaceController(fakeRepo);
      await controller.loadListings();

      expect(controller.state.listings.first.isFavorited, false);
      expect(controller.state.listings.first.favoriteCount, 2);

      await controller.toggleFavorite('fav-item');

      expect(controller.state.listings.first.isFavorited, true);
      expect(controller.state.listings.first.favoriteCount, 3);
      expect(fakeRepo.favoriteCalls, 1);

      // Toggle off
      await controller.toggleFavorite('fav-item');

      expect(controller.state.listings.first.isFavorited, false);
      expect(controller.state.listings.first.favoriteCount, 2);
      expect(fakeRepo.unfavoriteCalls, 1);
    });

    test('setFilter applies comprehensive filter object', () async {
      controller = MarketplaceController(fakeRepo);
      const newFilter = MarketplaceFilter(
        category: MarketplaceCategory.books,
        minPrice: 100,
        maxPrice: 500,
        sortBy: 'price_asc',
      );

      await controller.setFilter(newFilter);
      expect(controller.state.filter.category, MarketplaceCategory.books);
      expect(controller.state.filter.minPrice, 100);
      expect(controller.state.filter.maxPrice, 500);
      expect(controller.state.filter.sortBy, 'price_asc');
    });
  });
}
