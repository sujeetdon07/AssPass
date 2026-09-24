import '../../domain/entities/community_category.dart';
import '../../domain/entities/community_entity.dart';

/// Data model representing a Community DTO from the REST API.
class CommunityModel {
  const CommunityModel({
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

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    final creatorMap = json['creator'] as Map<String, dynamic>?;

    return CommunityModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: CommunityCategory.fromString(json['category'] as String?),
      visibility: json['visibility'] as String? ?? 'public',
      status: json['status'] as String? ?? 'active',
      creatorId:
          json['creatorId'] as String? ?? creatorMap?['id'] as String? ?? '',
      creatorName: json['creatorName'] as String? ??
          creatorMap?['displayName'] as String?,
      creatorAvatarUrl: json['creatorAvatarUrl'] as String? ??
          creatorMap?['avatarUrl'] as String?,
      countryCode: json['countryCode'] as String? ?? 'IN',
      state: json['state'] as String?,
      district: json['district'] as String?,
      city: json['city'] as String?,
      locality: json['locality'] as String?,
      neighborhood: json['neighborhood'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
      coverImageUrl: json['coverImageUrl'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      currentUserMember: json['currentUserMember'] as bool? ?? false,
      currentUserRole: json['currentUserRole'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'category': category.value,
      'visibility': visibility,
      'status': status,
      'creatorId': creatorId,
      if (creatorName != null) 'creatorName': creatorName,
      if (creatorAvatarUrl != null) 'creatorAvatarUrl': creatorAvatarUrl,
      'countryCode': countryCode,
      if (state != null) 'state': state,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (locality != null) 'locality': locality,
      if (neighborhood != null) 'neighborhood': neighborhood,
      'memberCount': memberCount,
      'postCount': postCount,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'currentUserMember': currentUserMember,
      if (currentUserRole != null) 'currentUserRole': currentUserRole,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  CommunityEntity toEntity() {
    return CommunityEntity(
      id: id,
      name: name,
      slug: slug,
      description: description,
      category: category,
      visibility: visibility,
      status: status,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
      countryCode: countryCode,
      state: state,
      district: district,
      city: city,
      locality: locality,
      neighborhood: neighborhood,
      memberCount: memberCount,
      postCount: postCount,
      coverImageUrl: coverImageUrl,
      avatarUrl: avatarUrl,
      currentUserMember: currentUserMember,
      currentUserRole: currentUserRole,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
