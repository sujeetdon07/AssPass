import 'community_category.dart';

/// Pure domain entity representing a Community in Aaspaas.
class CommunityEntity {
  const CommunityEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.category,
    this.visibility = 'public',
    this.status = 'active',
    required this.creatorId,
    this.creatorName,
    this.creatorAvatarUrl,
    this.countryCode = 'IN',
    this.state,
    this.district,
    this.city,
    this.locality,
    this.neighborhood,
    this.memberCount = 1,
    this.postCount = 0,
    this.coverImageUrl,
    this.avatarUrl,
    this.currentUserMember = false,
    this.currentUserRole,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final CommunityCategory category;
  final String visibility;
  final String status;
  final String creatorId;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final String countryCode;
  final String? state;
  final String? district;
  final String? city;
  final String? locality;
  final String? neighborhood;
  final int memberCount;
  final int postCount;
  final String? coverImageUrl;
  final String? avatarUrl;
  final bool currentUserMember;
  final String? currentUserRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPrivate => visibility.toLowerCase() == 'private';
  bool get isOwner => currentUserRole?.toLowerCase() == 'owner';
  bool get isModerator =>
      currentUserRole?.toLowerCase() == 'moderator' || isOwner;

  /// User-friendly display location summary.
  String get locationDisplay {
    if (neighborhood != null && locality != null) {
      return '$neighborhood, $locality';
    }
    if (locality != null && city != null) {
      return '$locality, $city';
    }
    if (locality != null) return locality!;
    if (city != null) return city!;
    return 'Local';
  }

  CommunityEntity copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    CommunityCategory? category,
    String? visibility,
    String? status,
    String? creatorId,
    String? creatorName,
    String? creatorAvatarUrl,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
    int? memberCount,
    int? postCount,
    String? coverImageUrl,
    String? avatarUrl,
    bool? currentUserMember,
    String? currentUserRole,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommunityEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      district: district ?? this.district,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      neighborhood: neighborhood ?? this.neighborhood,
      memberCount: memberCount ?? this.memberCount,
      postCount: postCount ?? this.postCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currentUserMember: currentUserMember ?? this.currentUserMember,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
