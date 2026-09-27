/// Domain model for a blocked user record.
class BlockedUserRecord {
  const BlockedUserRecord({
    required this.blockId,
    required this.blockedAt,
    required this.blockedUserId,
    required this.displayName,
    this.avatarUrl,
    this.locality,
    this.city,
  });

  factory BlockedUserRecord.fromJson(Map<String, dynamic> json) {
    final blockedUser = json['blockedUser'] as Map<String, dynamic>? ?? {};
    return BlockedUserRecord(
      blockId: json['blockId'] as String? ?? '',
      blockedAt: json['blockedAt'] != null
          ? DateTime.tryParse(json['blockedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      blockedUserId: blockedUser['id'] as String? ?? '',
      displayName: blockedUser['displayName'] as String? ?? 'Neighbor',
      avatarUrl: blockedUser['avatarUrl'] as String?,
      locality: blockedUser['locality'] as String?,
      city: blockedUser['city'] as String?,
    );
  }

  /// Unique ID of the block record (for unblock operations).
  final String blockId;

  /// When the block was created.
  final DateTime blockedAt;

  /// UUID of the blocked user.
  final String blockedUserId;

  /// Display name of the blocked user (safe public projection).
  final String displayName;

  /// Avatar URL (may be null).
  final String? avatarUrl;

  /// Locality of the blocked user (safe public projection).
  final String? locality;

  /// City of the blocked user (safe public projection).
  final String? city;
}
