import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_listing_entity.dart';

class ServiceProviderModel extends ServiceProviderEntity {
  const ServiceProviderModel({
    required super.id,
    required super.displayName,
    super.avatarUrl,
    super.locality,
    super.city,
  });

  factory ServiceProviderModel.fromJson(Map<String, dynamic> json) {
    return ServiceProviderModel(
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

class ServiceListingModel extends ServiceListingEntity {
  const ServiceListingModel({
    required super.id,
    required super.providerId,
    required super.provider,
    super.businessId,
    super.businessName,
    required super.title,
    required super.description,
    required super.category,
    required super.pricingModel,
    super.startingPrice,
    super.currency = 'INR',
    super.experienceYears,
    required super.status,
    super.countryCode = 'IN',
    super.state,
    super.district,
    super.city,
    super.locality,
    super.neighborhood,
    super.contactPhone,
    super.contactEmail,
    super.contactWhatsapp,
    super.serviceRadiusKm,
    super.serviceAreaDescription,
    super.favoriteCount = 0,
    super.isFavorited = false,
    super.isProvider = false,
    super.distance,
    super.distanceMeters,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ServiceListingModel.fromJson(Map<String, dynamic> json) {
    final providerMap =
        (json['provider'] ?? json['owner']) as Map<String, dynamic>? ?? {};

    return ServiceListingModel(
      id: json['id'] as String? ?? '',
      providerId: (json['providerId'] ?? json['ownerId']) as String? ?? '',
      provider: ServiceProviderModel.fromJson(providerMap),
      businessId: json['businessId'] as String?,
      businessName: json['businessName'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category:
          ServiceCategory.fromString(json['category'] as String? ?? 'other'),
      pricingModel: PricingModel.fromString(
        json['pricingModel'] as String? ?? 'contact_for_quote',
      ),
      startingPrice: (json['startingPrice'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      experienceYears: (json['experienceYears'] as num?)?.toInt(),
      status: ServiceStatus.fromString(json['status'] as String? ?? 'active'),
      countryCode: json['countryCode'] as String? ?? 'IN',
      state: json['state'] as String?,
      district: json['district'] as String?,
      city: json['city'] as String?,
      locality: json['locality'] as String?,
      neighborhood: json['neighborhood'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactWhatsapp: json['contactWhatsapp'] as String?,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble(),
      serviceAreaDescription: json['serviceAreaDescription'] as String?,
      favoriteCount: (json['favoriteCount'] as num?)?.toInt() ?? 0,
      isFavorited: json['isFavorited'] as bool? ?? false,
      isProvider: (json['isProvider'] ?? json['isOwner']) as bool? ?? false,
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
        'providerId': providerId,
        'provider': (provider as ServiceProviderModel).toJson(),
        'businessId': businessId,
        'businessName': businessName,
        'title': title,
        'description': description,
        'category': category.value,
        'pricingModel': pricingModel.value,
        'startingPrice': startingPrice,
        'currency': currency,
        'experienceYears': experienceYears,
        'status': status.value,
        'countryCode': countryCode,
        'state': state,
        'district': district,
        'city': city,
        'locality': locality,
        'neighborhood': neighborhood,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'contactWhatsapp': contactWhatsapp,
        'serviceRadiusKm': serviceRadiusKm,
        'serviceAreaDescription': serviceAreaDescription,
        'favoriteCount': favoriteCount,
        'isFavorited': isFavorited,
        'isProvider': isProvider,
        'distance': distance,
        'distanceMeters': distanceMeters,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class PaginatedServicesModel {
  const PaginatedServicesModel({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<ServiceListingModel> items;
  final String? nextCursor;
  final bool hasMore;

  factory PaginatedServicesModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedServicesModel(
      items: rawItems
          .map(
            (item) =>
                ServiceListingModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
