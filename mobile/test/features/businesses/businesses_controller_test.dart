import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/businesses/application/businesses_controller.dart';
import 'package:aaspaas/features/businesses/data/models/business_model.dart';
import 'package:aaspaas/features/businesses/data/repositories/businesses_repository.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_category.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_entity.dart';
import 'package:aaspaas/features/businesses/domain/entities/business_filter.dart';
import 'package:aaspaas/features/businesses/domain/entities/operating_hours.dart';
import 'package:aaspaas/features/nearby/application/location_controller.dart';
import 'package:aaspaas/features/nearby/domain/services/location_service.dart';

class _FakeBusinessesRepository extends Fake implements BusinessesRepository {
  List<BusinessModel> returnBusinesses = [];
  bool shouldThrow = false;
  String? nextCursor;
  bool hasMore = false;
  int favoriteCalls = 0;

  @override
  Future<PaginatedBusinessesModel> getBusinesses({
    String? query,
    BusinessCategory? category,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    double? radius,
    bool? openNow,
    BusinessSortOption? sortBy,
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return PaginatedBusinessesModel(
      items: returnBusinesses,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  @override
  Future<({bool isFavorited, int favoriteCount})> toggleFavorite(
    String id,
    bool favorite,
  ) async {
    favoriteCalls++;
    if (shouldThrow) throw Exception('Toggle favorite error');
    return (isFavorited: favorite, favoriteCount: favorite ? 1 : 0);
  }
}

BusinessModel _createBusiness({
  String id = 'b-1',
  String name = 'Local Bakery',
  BusinessCategory category = BusinessCategory.foodDining,
  bool isFavorited = false,
  int favoriteCount = 0,
}) {
  return BusinessModel(
    id: id,
    ownerId: 'owner-1',
    owner: const BusinessOwnerModel(
      id: 'owner-1',
      displayName: 'Baker Bob',
    ),
    name: name,
    slug: 'local-bakery',
    description: 'Fresh local bakery items',
    category: category,
    status: BusinessStatus.active,
    verificationStatus: BusinessVerificationStatus.unverified,
    operatingStatus: const OperatingStatusEntity(
      isOpen: true,
      status: 'open_now',
      statusText: 'Open Now',
    ),
    isFavorited: isFavorited,
    favoriteCount: favoriteCount,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

class _FakeLocationService extends Fake implements LocationService {}

void main() {
  group('BusinessesController', () {
    late _FakeBusinessesRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeBusinessesRepository();
      container = ProviderContainer(
        overrides: [
          businessesRepositoryProvider.overrideWithValue(fakeRepo),
          locationControllerProvider.overrideWith(
            (ref) => LocationController(_FakeLocationService()),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadBusinesses successfully populates state', () async {
      fakeRepo.returnBusinesses = [
        _createBusiness(id: 'b-1', name: 'Artisan Breads'),
        _createBusiness(id: 'b-2', name: 'City Hardware'),
      ];

      final controller = container.read(businessesControllerProvider.notifier);
      await controller.loadBusinesses();

      final state = container.read(businessesControllerProvider);
      expect(state.isLoading, false);
      expect(state.businesses.length, 2);
      expect(state.businesses.first.name, 'Artisan Breads');
      expect(state.errorMessage, isNull);
    });

    test('loadBusinesses handles network failure gracefully', () async {
      fakeRepo.shouldThrow = true;

      final controller = container.read(businessesControllerProvider.notifier);
      await controller.loadBusinesses();

      final state = container.read(businessesControllerProvider);
      expect(state.isLoading, false);
      expect(state.errorMessage, isNotNull);
      expect(state.businesses, isEmpty);
    });

    test('setCategory updates filter and triggers reload', () async {
      fakeRepo.returnBusinesses = [
        _createBusiness(
          id: 'b-grocery',
          name: 'Corner Store',
          category: BusinessCategory.grocery,
        ),
      ];

      final controller = container.read(businessesControllerProvider.notifier);
      controller.setCategory(BusinessCategory.grocery);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(businessesControllerProvider);
      expect(state.filter.category, BusinessCategory.grocery);
      expect(state.businesses.length, 1);
      expect(state.businesses.first.category, BusinessCategory.grocery);
    });

    test('setSearchQuery updates query in filter', () async {
      fakeRepo.returnBusinesses = [
        _createBusiness(id: 'b-search', name: 'Fresh Juice Bar'),
      ];

      final controller = container.read(businessesControllerProvider.notifier);
      controller.setSearchQuery('Juice');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(businessesControllerProvider);
      expect(state.filter.searchQuery, 'Juice');
    });

    test('toggleFavorite updates favorite state optimistically', () async {
      fakeRepo.returnBusinesses = [
        _createBusiness(
          id: 'b-fav',
          name: 'Fav Cafe',
          isFavorited: false,
          favoriteCount: 2,
        ),
      ];

      final controller = container.read(businessesControllerProvider.notifier);
      await controller.loadBusinesses();

      await controller.toggleFavorite('b-fav');

      final state = container.read(businessesControllerProvider);
      expect(state.businesses.first.isFavorited, true);
      expect(state.businesses.first.favoriteCount, 3);
      expect(fakeRepo.favoriteCalls, 1);
    });
  });
}
