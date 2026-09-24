import 'marketplace_category.dart';
import 'marketplace_condition.dart';

/// Filter state model for Marketplace discovery.
class MarketplaceFilter {
  const MarketplaceFilter({
    this.query,
    this.category,
    this.condition,
    this.minPrice,
    this.maxPrice,
    this.radiusKm = 5,
    this.sortBy = 'newest',
    this.locality,
    this.city,
  });

  final String? query;
  final MarketplaceCategory? category;
  final MarketplaceCondition? condition;
  final double? minPrice;
  final double? maxPrice;
  final int radiusKm;
  final String sortBy;
  final String? locality;
  final String? city;

  bool get hasActiveFilters =>
      category != null ||
      condition != null ||
      minPrice != null ||
      maxPrice != null ||
      sortBy != 'newest' ||
      radiusKm != 5;

  MarketplaceFilter copyWith({
    String? query,
    MarketplaceCategory? category,
    bool clearCategory = false,
    MarketplaceCondition? condition,
    bool clearCondition = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    int? radiusKm,
    String? sortBy,
    String? locality,
    bool clearLocality = false,
    String? city,
    bool clearCity = false,
  }) {
    return MarketplaceFilter(
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      condition: clearCondition ? null : (condition ?? this.condition),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      radiusKm: radiusKm ?? this.radiusKm,
      sortBy: sortBy ?? this.sortBy,
      locality: clearLocality ? null : (locality ?? this.locality),
      city: clearCity ? null : (city ?? this.city),
    );
  }

  MarketplaceFilter clearAll() {
    return const MarketplaceFilter(radiusKm: 5, sortBy: 'newest');
  }
}
