import 'business_category.dart';
import 'operating_hours.dart';

enum BusinessStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  archived('archived', 'Archived');

  const BusinessStatus(this.value, this.label);
  final String value;
  final String label;

  static BusinessStatus fromString(String? value) {
    if (value == null) return BusinessStatus.active;
    return BusinessStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => BusinessStatus.active,
    );
  }
}

enum BusinessVerificationStatus {
  unverified('unverified', 'Unverified'),
  pending('pending', 'Pending Review'),
  verified('verified', 'Verified');

  const BusinessVerificationStatus(this.value, this.label);
  final String value;
  final String label;

  static BusinessVerificationStatus fromString(String? value) {
    if (value == null) return BusinessVerificationStatus.unverified;
    return BusinessVerificationStatus.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => BusinessVerificationStatus.unverified,
    );
  }
}

class BusinessImageEntity {
  const BusinessImageEntity({
    required this.id,
    required this.url,
    this.displayOrder = 0,
  });

  final String id;
  final String url;
  final int displayOrder;
}

class BusinessServiceEntity {
  const BusinessServiceEntity({
    required this.id,
    required this.name,
    this.description,
    this.startingPrice,
    this.currency = 'INR',
  });

  final String id;
  final String name;
  final String? description;
  final double? startingPrice;
  final String currency;
}

class BusinessOwnerEntity {
  const BusinessOwnerEntity({
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

class BusinessEntity {
  const BusinessEntity({
    required this.id,
    required this.ownerId,
    required this.owner,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    required this.status,
    required this.verificationStatus,
    this.countryCode = 'IN',
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
    this.address,
    this.contactPhone,
    this.contactEmail,
    this.website,
    this.timezone = 'Asia/Kolkata',
    this.operatingHours,
    required this.operatingStatus,
    this.favoriteCount = 0,
    this.isFavorited = false,
    this.isOwner = false,
    this.images = const [],
    this.services = const [],
    this.distance,
    this.distanceMeters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final BusinessOwnerEntity owner;
  final String name;
  final String slug;
  final String description;
  final BusinessCategory category;
  final BusinessStatus status;
  final BusinessVerificationStatus verificationStatus;
  final String countryCode;
  final String? state;
  final String? district;
  final String? city;
  final String? locality;
  final String? neighborhood;
  final String? address;
  final String? contactPhone;
  final String? contactEmail;
  final String? website;
  final String timezone;
  final OperatingHoursEntity? operatingHours;
  final OperatingStatusEntity operatingStatus;
  final int favoriteCount;
  final bool isFavorited;
  final bool isOwner;
  final List<BusinessImageEntity> images;
  final List<BusinessServiceEntity> services;
  final String? distance;
  final int? distanceMeters;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get locationSummary {
    final parts = [locality, city].where((p) => p != null && p.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(', ');
    return 'Local area';
  }

  String? get primaryImageUrl => images.isNotEmpty ? images.first.url : null;
}
