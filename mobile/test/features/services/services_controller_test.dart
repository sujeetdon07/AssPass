import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/nearby/application/location_controller.dart';
import 'package:aaspaas/features/services/application/services_controller.dart';
import 'package:aaspaas/features/services/data/models/service_listing_model.dart';
import 'package:aaspaas/features/services/data/repositories/services_repository.dart';
import 'package:aaspaas/features/services/domain/entities/service_category.dart';
import 'package:aaspaas/features/services/domain/entities/service_filter.dart';
import 'package:aaspaas/features/nearby/domain/services/location_service.dart';

class _FakeLocationService extends Fake implements LocationService {}

class _FakeServicesRepository extends Fake implements ServicesRepository {
  List<ServiceListingModel> returnServices = [];
  bool shouldThrow = false;
  String? nextCursor;
  bool hasMore = false;
  int favoriteCalls = 0;

  @override
  Future<PaginatedServicesModel> getServices({
    String? query,
    ServiceCategory? category,
    PricingModel? pricingModel,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    double? radius,
    ServiceSortOption? sortBy,
    String? cursor,
    int limit = 20,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return PaginatedServicesModel(
      items: returnServices,
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

ServiceListingModel _createService({
  String id = 's-1',
  String title = 'Plumbing Service',
  ServiceCategory category = ServiceCategory.plumber,
  PricingModel pricingModel = PricingModel.hourly,
  double startingPrice = 300,
  bool isFavorited = false,
  int favoriteCount = 0,
}) {
  return ServiceListingModel(
    id: id,
    providerId: 'prov-1',
    provider: const ServiceProviderModel(
      id: 'prov-1',
      displayName: 'Plumber Pete',
    ),
    title: title,
    description: 'All pipe and leak repairs',
    category: category,
    pricingModel: pricingModel,
    startingPrice: startingPrice,
    status: ServiceStatus.active,
    isFavorited: isFavorited,
    favoriteCount: favoriteCount,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  group('ServicesController', () {
    late _FakeServicesRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = _FakeServicesRepository();
      container = ProviderContainer(
        overrides: [
          servicesRepositoryProvider.overrideWithValue(fakeRepo),
          locationControllerProvider.overrideWith(
            (ref) => LocationController(_FakeLocationService()),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('loadServices successfully populates state', () async {
      fakeRepo.returnServices = [
        _createService(id: 's-1', title: 'Electric Repair'),
        _createService(id: 's-2', title: 'Wall Painting'),
      ];

      final controller = container.read(servicesControllerProvider.notifier);
      await controller.loadServices();

      final state = container.read(servicesControllerProvider);
      expect(state.isLoading, false);
      expect(state.services.length, 2);
      expect(state.services.first.title, 'Electric Repair');
      expect(state.errorMessage, isNull);
    });

    test('loadServices handles network error', () async {
      fakeRepo.shouldThrow = true;

      final controller = container.read(servicesControllerProvider.notifier);
      await controller.loadServices();

      final state = container.read(servicesControllerProvider);
      expect(state.isLoading, false);
      expect(state.errorMessage, isNotNull);
      expect(state.services, isEmpty);
    });

    test('setCategory updates filter and reloads', () async {
      fakeRepo.returnServices = [
        _createService(
          id: 's-tutor',
          title: 'Maths Teacher',
          category: ServiceCategory.tutor,
        ),
      ];

      final controller = container.read(servicesControllerProvider.notifier);
      controller.setCategory(ServiceCategory.tutor);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(servicesControllerProvider);
      expect(state.filter.category, ServiceCategory.tutor);
      expect(state.services.length, 1);
      expect(state.services.first.category, ServiceCategory.tutor);
    });

    test('setPricingModel updates pricing model filter', () async {
      final controller = container.read(servicesControllerProvider.notifier);
      controller.setPricingModel(PricingModel.hourly);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(servicesControllerProvider);
      expect(state.filter.pricingModel, PricingModel.hourly);
    });

    test('toggleFavorite updates favorite state optimistically', () async {
      fakeRepo.returnServices = [
        _createService(
          id: 's-fav',
          title: 'Top Plumber',
          isFavorited: false,
          favoriteCount: 1,
        ),
      ];

      final controller = container.read(servicesControllerProvider.notifier);
      await controller.loadServices();

      await controller.toggleFavorite('s-fav');

      final state = container.read(servicesControllerProvider);
      expect(state.services.first.isFavorited, true);
      expect(state.services.first.favoriteCount, 2);
      expect(fakeRepo.favoriteCalls, 1);
    });
  });
}
