import 'message_entity.dart';

class ConversationParticipantProfile {
  const ConversationParticipantProfile({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.locality,
    this.city,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String? locality;
  final String? city;

  /// Formatted handle e.g. '@sujeet'
  String? get handle =>
      username != null && username!.trim().isNotEmpty ? '@${username!.trim()}' : null;

  String get localitySummary {
    if (locality != null && locality!.isNotEmpty) {
      if (city != null && city!.isNotEmpty) {
        return '$locality, $city';
      }
      return locality!;
    }
    return city ?? 'Aaspaas';
  }
}

class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.participant,
    this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String id;
  final ConversationParticipantProfile participant;
  final MessageEntity? lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isOnline;

  bool get hasUnread => unreadCount > 0;

  ConversationEntity copyWith({
    String? id,
    ConversationParticipantProfile? participant,
    MessageEntity? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      participant: participant ?? this.participant,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
