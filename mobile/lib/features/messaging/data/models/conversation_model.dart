import '../../domain/entities/conversation_entity.dart';
import 'message_model.dart';

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.participant,
    super.lastMessage,
    required super.lastMessageAt,
    super.unreadCount = 0,
    super.isOnline = false,
  });

  factory ConversationModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final participantJson = json['participant'] as Map<String, dynamic>? ?? {};
    final participant = ConversationParticipantProfile(
      id: participantJson['id'] as String? ?? '',
      displayName: participantJson['displayName'] as String? ?? 'Neighbor',
      username: participantJson['username'] as String?,
      avatarUrl: participantJson['avatarUrl'] as String?,
      locality: participantJson['locality'] as String?,
      city: participantJson['city'] as String?,
    );

    final lastMessageJson = json['lastMessage'] as Map<String, dynamic>?;
    final lastMessage = lastMessageJson != null
        ? MessageModel.fromJson(lastMessageJson, currentUserId: currentUserId)
        : null;

    final lastMessageAtStr = json['lastMessageAt'] as String?;
    final lastMessageAt = lastMessageAtStr != null
        ? DateTime.tryParse(lastMessageAtStr) ?? DateTime.now()
        : DateTime.now();

    return ConversationModel(
      id: json['id'] as String? ?? '',
      participant: participant,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }
}
