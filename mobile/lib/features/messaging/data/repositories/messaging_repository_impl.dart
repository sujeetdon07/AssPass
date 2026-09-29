import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_datasource.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final remoteDataSource = ref.watch(messagingRemoteDataSourceProvider);
  final authState = ref.watch(authControllerProvider);
  String? userId;
  if (authState is AuthAuthenticated) {
    userId = authState.user.id;
  } else if (authState is AuthOnboardingRequired) {
    userId = authState.user.id;
  }
  return MessagingRepositoryImpl(remoteDataSource, userId);
});

class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl(this._remoteDataSource, this._currentUserId);

  final MessagingRemoteDataSource _remoteDataSource;
  final String? _currentUserId;

  @override
  Future<ConversationEntity> createOrGetConversation(
    String participantId,
  ) async {
    return _remoteDataSource.createOrGetConversation(
      participantId,
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<({List<ConversationEntity> items, String? nextCursor, bool hasMore})>
      getConversations({String? cursor, int limit = 20}) async {
    return _remoteDataSource.getConversations(
      cursor: cursor,
      limit: limit,
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<ConversationEntity> getConversationById(String conversationId) async {
    return _remoteDataSource.getConversationById(
      conversationId,
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<({List<MessageEntity> items, String? nextCursor, bool hasMore})>
      getMessages(
    String conversationId, {
    String? cursor,
    int limit = 30,
  }) async {
    return _remoteDataSource.getMessages(
      conversationId,
      cursor: cursor,
      limit: limit,
      currentUserId: _currentUserId,
    );
  }

  @override
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
  }) async {
    return _remoteDataSource.sendMessage(
      conversationId,
      clientMessageId: clientMessageId,
      content: content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      mediaSize: mediaSize,
      mediaMimeType: mediaMimeType,
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    await _remoteDataSource.markAsRead(conversationId);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _remoteDataSource.deleteMessage(messageId);
  }

  @override
  Future<void> reportConversation(
    String conversationId, {
    required String reason,
    String? description,
    String? messageId,
  }) async {
    await _remoteDataSource.reportConversation(
      conversationId,
      reason: reason,
      description: description,
      messageId: messageId,
    );
  }

  @override
  Future<void> blockUser(String userId) async {
    await _remoteDataSource.blockUser(userId);
  }

  @override
  Future<void> unblockUser(String userId) async {
    await _remoteDataSource.unblockUser(userId);
  }

  @override
  Future<bool> getPresence(String userId) async {
    return _remoteDataSource.getPresence(userId);
  }
}
