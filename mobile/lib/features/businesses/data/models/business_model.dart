import '../../domain/entities/business_category.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/operating_hours.dart';

class BusinessImageModel extends BusinessImageEntity {
  const BusinessImageModel({
    required super.id,
    required super.url,
    super.displayOrder = 0,
  });

  factory BusinessImageModel.fromJson(Map<String, dynamic> json) {
    return BusinessImageModel(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'displayOrder': displayOrder,
      };
}

class BusinessServiceModel extends BusinessServiceEntity {
  const BusinessServiceModel({
    required super.id,
    required super.name,
    super.description,
    super.startingPrice,
    super.currency = 'INR',
  });

  factory BusinessServiceModel.fromJson(Map<String, dynamic> json) {
    return BusinessServiceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      startingPrice: (json['startingPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'startingPrice': startingPrice,
        'currency': currency,
      };
}

class BusinessOwnerModel extends BusinessOwnerEntity {
  const BusinessOwnerModel({
    required super.id,
    required super.displayName,
    super.avatarUrl,
    super.locality,
    super.city,
  });

  factory BusinessOwnerModel.fromJson(Map<String, dynamic> json) {
    return BusinessOwnerModel(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Neighbor',
      avatarUrl: json['avatarUrl'] as String?,
      locality: json['locality'] as String?,
      city: json['city'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'locality': locality,
        'city': city,
      };
}

class BusinessModel extends BusinessEntity {
  const BusinessModel({
    required super.id,
    required super.ownerId,
    required super.owner,
    required super.name,
    required super.slug,
    required super.description,
    required super.category,
    required super.status,
    required super.verificationStatus,
    super.countryCode = 'IN',
    super.state,
    super.district,
    super.city,
    super.locality,
    super.neighborhood,
    super.address,
    super.contactPhone,
    super.contactEmail,
    super.website,
    super.timezone = 'Asia/Kolkata',
    super.operatingHours,
    required super.operatingStatus,
    super.favoriteCount = 0,
    super.isFavorited = false,
    super.isOwner = false,
    super.images = const [],
    super.services = const [],
    super.distance,
    super.distanceMeters,
    required super.createdAt,
    required super.updatedAt,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    final ownerMap = json['owner'] as Map<String, dynamic>? ?? {};
    final rawImages = json['images'] as List<dynamic>? ?? [];
    final rawServices = json['services'] as List<dynamic>? ?? [];
    final rawOperatingHours = json['operatingHours'] as Map<String, dynamic>?;
    final rawOperatingStatus =
        json['operatingStatus'] as Map<String, dynamic>? ?? {};

    return BusinessModel(
      id: json['id'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      owner: BusinessOwnerModel.fromJson(ownerMap),
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: BusinessCategory.fromString(json['category'] as String?),
      status: BusinessStatus.fromString(json['status'] as String?),
      verificationStatus: BusinessVerificationStatus.fromString(
        json['verificationStatus'] as String?,
      ),
      countryCode: json['countryCode'] as String? ?? 'IN',
      state: json['state'] as String?,
      district: json['district'] as String?,
      city: json['city'] as String?,
      locality: json['locality'] as String?,
      neighborhood: json['neighborhood'] as String?,
      address: json['address'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      website: json['website'] as String?,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
      operatingHours: rawOperatingHours != null
          ? OperatingHoursEntity.fromJson(rawOperatingHours)
          : null,
      operatingStatus: OperatingStatusEntity.fromJson(rawOperatingStatus),
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      isFavorited: json['isFavorited'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
      images: rawImages
          .map((i) => BusinessImageModel.fromJson(i as Map<String, dynamic>))
          .toList(),
      services: rawServices
          .map((s) => BusinessServiceModel.fromJson(s as Map<String, dynamic>))
          .toList(),
      distance: json['distance'] as String?,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'owner': (owner as BusinessOwnerModel).toJson(),
        'name': name,
        'slug': slug,
        'description': description,
        'category': category.value,
        'status': status.value,
        'verificationStatus': verificationStatus.value,
        'countryCode': countryCode,
        'state': state,
        'district': district,
        'city': city,
        'locality': locality,
        'neighborhood': neighborhood,
        'address': address,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'website': website,
        'timezone': timezone,
        'operatingHours': operatingHours?.toJson(),
        'favoriteCount': favoriteCount,
        'isFavorited': isFavorited,
        'isOwner': isOwner,
        'images':
            images.map((i) => (i as BusinessImageModel).toJson()).toList(),
        'services':
            services.map((s) => (s as BusinessServiceModel).toJson()).toList(),
        'distance': distance,
        'distanceMeters': distanceMeters,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class PaginatedBusinessesModel {
  const PaginatedBusinessesModel({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<BusinessModel> items;
  final String? nextCursor;
  final bool hasMore;

  factory PaginatedBusinessesModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedBusinessesModel(
      items: rawItems
          .map((item) => BusinessModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
