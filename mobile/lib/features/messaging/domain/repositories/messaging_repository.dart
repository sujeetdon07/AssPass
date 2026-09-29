import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';
export '../../data/repositories/messaging_repository_impl.dart'
    show messagingRepositoryProvider;

abstract class MessagingRepository {
  Future<ConversationEntity> createOrGetConversation(String participantId);

  Future<({List<ConversationEntity> items, String? nextCursor, bool hasMore})>
      getConversations({String? cursor, int limit = 20});

  Future<ConversationEntity> getConversationById(String conversationId);

  Future<({List<MessageEntity> items, String? nextCursor, bool hasMore})>
      getMessages(String conversationId, {String? cursor, int limit = 30});

  Future<MessageEntity> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String content,
    String messageType = 'TEXT',
    String? mediaUrl,
    String? mediaThumbnailUrl,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaSize,
    String? mediaMimeType,
  });

  Future<void> markAsRead(String conversationId);

  Future<void> deleteMessage(String messageId);

  Future<void> reportConversation(
    String conversationId, {
    required String reason,
    String? description,
    String? messageId,
  });

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<bool> getPresence(String userId);
}
