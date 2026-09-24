import 'marketplace_category.dart';
import 'marketplace_condition.dart';
import 'marketplace_status.dart';
import 'seller_profile_entity.dart';

/// Media image associated with a marketplace listing.
class ListingImageEntity {
  const ListingImageEntity({
    required this.id,
    required this.url,
    this.displayOrder = 0,
  });

  final String id;
  final String url;
  final int displayOrder;

  factory ListingImageEntity.fromJson(Map<String, dynamic> json) {
    return ListingImageEntity(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'displayOrder': displayOrder,
    };
  }
}

/// Core domain entity for an Aaspaas Marketplace listing.
class MarketplaceListingEntity {
  const MarketplaceListingEntity({
    required this.id,
    required this.sellerId,
    required this.seller,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.currency = 'INR',
    required this.condition,
    required this.status,
    this.countryCode = 'IN',
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.isOwner = false,
    this.images = const [],
    this.distance,
    this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sellerId;
  final SellerProfileEntity seller;
  final String title;
  final String description;
  final MarketplaceCategory category;
  final double price;
  final String currency;
  final MarketplaceCondition condition;
  final MarketplaceListingStatus status;
  final String countryCode;
  final String? state;
  final String? district;
  final String? city;
  final String? locality;
  final String? neighborhood;
  final int favoriteCount;
  final bool isFavorited;
  final bool isOwner;
  final List<ListingImageEntity> images;
  final String? distance;
  final int? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFree => price <= 0;

  bool get isActive => status == MarketplaceListingStatus.active;
  bool get isSold => status == MarketplaceListingStatus.sold;
  bool get isArchived => status == MarketplaceListingStatus.archived;

  String? get primaryImageUrl => images.isNotEmpty ? images.first.url : null;

  String get formattedPrice {
    if (isFree) return 'Free';
    final isWhole = price.truncateToDouble() == price;
    final formattedNum =
        isWhole ? price.toInt().toString() : price.toStringAsFixed(2);
    if (currency == 'INR') {
      return '₹$formattedNum';
    }
    return '$currency $formattedNum';
  }

  String get locationSummary {
    if (locality != null && city != null) {
      return '$locality, $city';
    }
    return locality ?? city ?? 'Nearby';
  }

  MarketplaceListingEntity copyWith({
    String? id,
    String? sellerId,
    SellerProfileEntity? seller,
    String? title,
    String? description,
    MarketplaceCategory? category,
    double? price,
    String? currency,
    MarketplaceCondition? condition,
    MarketplaceListingStatus? status,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
    int? favoriteCount,
    bool? isFavorited,
    bool? isOwner,
    List<ListingImageEntity>? images,
    String? distance,
    int? distanceMeters,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketplaceListingEntity(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      seller: seller ?? this.seller,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      condition: condition ?? this.condition,
      status: status ?? this.status,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      neighborhood: neighborhood ?? this.neighborhood,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      isFavorited: isFavorited ?? this.isFavorited,
      isOwner: isOwner ?? this.isOwner,
      images: images ?? this.images,
      distance: distance ?? this.distance,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
