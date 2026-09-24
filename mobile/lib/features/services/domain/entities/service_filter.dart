import 'service_category.dart';

enum ServiceSortOption {
  newest('newest', 'Recently Added'),
  distance('distance', 'Nearest to me'),
  priceAsc('price_asc', 'Price: Low to High'),
  priceDesc('price_desc', 'Price: High to Low');

  const ServiceSortOption(this.value, this.label);
  final String value;
  final String label;
}

class ServiceFilter {
  const ServiceFilter({
    this.searchQuery,
    this.category,
    this.pricingModel,
    this.locality,
    this.radiusKm,
    this.sortBy = ServiceSortOption.newest,
  });

  final String? searchQuery;
  final ServiceCategory? category;
  final PricingModel? pricingModel;
  final String? locality;
  final double? radiusKm;
  final ServiceSortOption sortBy;

  bool get hasActiveFilters =>
      category != null ||
      pricingModel != null ||
      (locality != null && locality!.isNotEmpty) ||
      radiusKm != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  ServiceFilter copyWith({
    String? searchQuery,
    ServiceCategory? category,
    PricingModel? pricingModel,
    String? locality,
    double? radiusKm,
    ServiceSortOption? sortBy,
    bool clearCategory = false,
    bool clearPricing = false,
    bool clearLocality = false,
    bool clearRadius = false,
    bool clearSearch = false,
  }) {
    return ServiceFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      category: clearCategory ? null : (category ?? this.category),
      pricingModel: clearPricing ? null : (pricingModel ?? this.pricingModel),
      locality: clearLocality ? null : (locality ?? this.locality),
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
