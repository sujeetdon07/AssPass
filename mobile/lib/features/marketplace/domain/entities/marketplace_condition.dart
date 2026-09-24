/// Controlled item condition values for Marketplace.
enum MarketplaceCondition {
  brandNew('new', 'Brand New'),
  likeNew('like_new', 'Like New'),
  good('good', 'Good Condition'),
  fair('fair', 'Fair Condition'),
  used('used', 'Used');

  const MarketplaceCondition(this.value, this.label);

  final String value;
  final String label;

  static MarketplaceCondition fromString(String? val) {
    if (val == null) return MarketplaceCondition.good;
    return MarketplaceCondition.values.firstWhere(
      (c) => c.value.toLowerCase() == val.toLowerCase(),
      orElse: () => MarketplaceCondition.good,
    );
  }
}
