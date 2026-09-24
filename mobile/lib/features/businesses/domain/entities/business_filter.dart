import 'business_category.dart';

enum BusinessSortOption {
  newest('newest', 'Recently Added'),
  nearest('nearest', 'Nearest to me');

  const BusinessSortOption(this.value, this.label);
  final String value;
  final String label;
}

class BusinessFilter {
  const BusinessFilter({
    this.searchQuery,
    this.category,
    this.locality,
    this.radiusKm,
    this.openNow = false,
    this.sortBy = BusinessSortOption.newest,
  });

  final String? searchQuery;
  final BusinessCategory? category;
  final String? locality;
  final double? radiusKm;
  final bool openNow;
  final BusinessSortOption sortBy;

  bool get hasActiveFilters =>
      category != null ||
      (locality != null && locality!.isNotEmpty) ||
      radiusKm != null ||
      openNow ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  BusinessFilter copyWith({
    String? searchQuery,
    BusinessCategory? category,
    String? locality,
    double? radiusKm,
    bool? openNow,
    BusinessSortOption? sortBy,
    bool clearCategory = false,
    bool clearLocality = false,
    bool clearRadius = false,
    bool clearSearch = false,
  }) {
    return BusinessFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      category: clearCategory ? null : (category ?? this.category),
      locality: clearLocality ? null : (locality ?? this.locality),
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
      openNow: openNow ?? this.openNow,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}
