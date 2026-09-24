/// Controlled listing lifecycle status for Marketplace.
enum MarketplaceListingStatus {
  active('active', 'Active'),
  sold('sold', 'Sold'),
  archived('archived', 'Archived');

  const MarketplaceListingStatus(this.value, this.label);

  final String value;
  final String label;

  static MarketplaceListingStatus fromString(String? val) {
    if (val == null) return MarketplaceListingStatus.active;
    return MarketplaceListingStatus.values.firstWhere(
      (s) => s.value.toLowerCase() == val.toLowerCase(),
      orElse: () => MarketplaceListingStatus.active,
    );
  }
}
