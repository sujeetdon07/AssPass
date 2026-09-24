import '../../domain/entities/community_member_entity.dart';

/// Data model representing a Community Member DTO from the REST API.
class CommunityMemberModel {
  const CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.locality,
    this.city,
    required this.role,
    this.status = 'active',
    required this.joinedAt,
  });

  final String id;
  final String communityId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? locality;
  final String? city;
  final String role;
  final String status;
  final DateTime joinedAt;

  factory CommunityMemberModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;

    return CommunityMemberModel(
      id: json['id'] as String? ?? '',
      communityId: json['communityId'] as String? ?? '',
      userId: json['userId'] as String? ?? userMap?['id'] as String? ?? '',
      displayName: json['displayName'] as String? ??
          userMap?['displayName'] as String? ??
          'Neighbor',
      avatarUrl:
          json['avatarUrl'] as String? ?? userMap?['avatarUrl'] as String?,
      locality: json['locality'] as String? ?? userMap?['locality'] as String?,
      city: json['city'] as String? ?? userMap?['city'] as String?,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'active',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'communityId': communityId,
      'userId': userId,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (locality != null) 'locality': locality,
      if (city != null) 'city': city,
      'role': role,
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  CommunityMemberEntity toEntity() {
    return CommunityMemberEntity(
      id: id,
      communityId: communityId,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      locality: locality,
      city: city,
      role: role,
      status: status,
      joinedAt: joinedAt,
    );
  }
}
