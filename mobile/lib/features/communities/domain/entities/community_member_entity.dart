/// Pure domain entity representing a Community Member.
class CommunityMemberEntity {
  const CommunityMemberEntity({
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

  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isModerator => role.toLowerCase() == 'moderator' || isOwner;

  String get locationSummary {
    if (locality != null && city != null) {
      return '$locality, $city';
    }
    return locality ?? city ?? '';
  }
}
