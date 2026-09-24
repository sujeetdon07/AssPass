import 'service_category.dart';

class ServiceProviderEntity {
  const ServiceProviderEntity({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.locality,
    this.city,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? locality;
  final String? city;
}

class ServiceListingEntity {
  const ServiceListingEntity({
    required this.id,
    required this.providerId,
    required this.provider,
    this.businessId,
    this.businessName,
    required this.title,
    required this.description,
    required this.category,
    required this.pricingModel,
    this.startingPrice,
    this.currency = 'INR',
    this.experienceYears,
    required this.status,
    this.countryCode = 'IN',
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
    this.contactPhone,
    this.contactEmail,
    this.contactWhatsapp,
    this.serviceRadiusKm,
    this.serviceAreaDescription,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.isProvider = false,
    this.distance,
    this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String providerId;
  final ServiceProviderEntity provider;
  final String? businessId;
  final String? businessName;
  final String title;
  final String description;
  final ServiceCategory category;
  final PricingModel pricingModel;
  final double? startingPrice;
  final String currency;
  final int? experienceYears;
  final ServiceStatus status;
  final String countryCode;
  final String? state;
  final String? district;
  final String? city;
  final String? locality;
  final String? neighborhood;
  final String? contactPhone;
  final String? contactEmail;
  final String? contactWhatsapp;
  final double? serviceRadiusKm;
  final String? serviceAreaDescription;
  final int favoriteCount;
  final bool isFavorited;
  final bool isProvider;
  final String? distance;
  final int? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get locationSummary {
    final parts = [locality, city].where((p) => p != null && p.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return 'Local area';
  }

  String get formattedPrice {
    switch (pricingModel) {
      case PricingModel.fixed:
        return startingPrice != null
            ? '₹${startingPrice!.toStringAsFixed(startingPrice! % 1 == 0 ? 0 : 2)}'
            : 'Fixed price';
      case PricingModel.hourly:
        return startingPrice != null
            ? '₹${startingPrice!.toStringAsFixed(startingPrice! % 1 == 0 ? 0 : 2)}/hr'
            : 'Per hour';
      case PricingModel.startingAt:
        return startingPrice != null
            ? 'From ₹${startingPrice!.toStringAsFixed(startingPrice! % 1 == 0 ? 0 : 2)}'
            : 'Starting rate';
      case PricingModel.contactForQuote:
        return 'Contact for quote';
    }
  }
}
