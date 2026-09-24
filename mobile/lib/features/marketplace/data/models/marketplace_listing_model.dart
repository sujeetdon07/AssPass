import '../../domain/entities/marketplace_category.dart';
import '../../domain/entities/marketplace_condition.dart';
import '../../domain/entities/marketplace_listing_entity.dart';
import '../../domain/entities/marketplace_status.dart';
import '../../domain/entities/seller_profile_entity.dart';

class MarketplaceListingModel {
  const MarketplaceListingModel({
    required this.id,
    required this.sellerId,
    required this.seller,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.currency,
    required this.condition,
    required this.status,
    required this.countryCode,
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
    required this.favoriteCount,
    required this.isFavorited,
    required this.isOwner,
    required this.images,
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

  factory MarketplaceListingModel.fromJson(Map<String, dynamic> json) {
    final sellerJson = json['seller'] as Map<String, dynamic>? ?? {};
    final rawImages = json['images'] as List<dynamic>? ?? [];

    double parsedPrice = 0.0;
    if (json['price'] != null) {
      if (json['price'] is num) {
        parsedPrice = (json['price'] as num).toDouble();
      } else {
        parsedPrice = double.tryParse(json['price'].toString()) ?? 0.0;
      }
    }

    return MarketplaceListingModel(
      id: json['id'] as String? ?? '',
      sellerId: json['sellerId'] as String? ?? '',
      seller: SellerProfileEntity.fromJson(sellerJson),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: MarketplaceCategory.fromString(json['category'] as String?),
      price: parsedPrice,
      currency: json['currency'] as String? ?? 'INR',
      condition: MarketplaceCondition.fromString(json['condition'] as String?),
      status: MarketplaceListingStatus.fromString(json['status'] as String?),
      countryCode: json['countryCode'] as String? ?? 'IN',
      state: json['state'] as String?,
      district: json['district'] as String?,
      city: json['city'] as String?,
      locality: json['locality'] as String?,
      neighborhood: json['neighborhood'] as String?,
      favoriteCount: json['favoriteCount'] as int? ?? 0,
      isFavorited: json['isFavorited'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      images: rawImages
          .map(
            (img) => ListingImageEntity.fromJson(img as Map<String, dynamic>),
          )
          .toList(),
      distance: json['distance'] as String?,
      distanceMeters: json['distanceMeters'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  MarketplaceListingEntity toEntity() {
    return MarketplaceListingEntity(
      id: id,
      sellerId: sellerId,
      seller: seller,
      title: title,
      description: description,
      category: category,
      price: price,
      currency: currency,
      condition: condition,
      status: status,
      countryCode: countryCode,
      state: state,
      district: district,
      city: city,
      locality: locality,
      neighborhood: neighborhood,
      favoriteCount: favoriteCount,
      isFavorited: isFavorited,
      isOwner: isOwner,
      images: images,
      distance: distance,
      distanceMeters: distanceMeters,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class MarketplaceListingPageModel {
  const MarketplaceListingPageModel({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<MarketplaceListingEntity> items;
  final String? nextCursor;
  final bool hasMore;

  factory MarketplaceListingPageModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MarketplaceListingPageModel(
      items: rawItems
          .map(
            (item) =>
                MarketplaceListingModel.fromJson(item as Map<String, dynamic>)
                    .toEntity(),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
