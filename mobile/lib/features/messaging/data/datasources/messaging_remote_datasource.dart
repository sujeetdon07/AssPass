import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

final messagingRemoteDataSourceProvider =
    Provider<MessagingRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return MessagingRemoteDataSource(dio);
});

class MessagingRemoteDataSource {
  MessagingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ConversationModel> createOrGetConversation(
    String participantId, {
    String? currentUserId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/messaging/conversations',
      data: {'participantId': participantId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return ConversationModel.fromJson(data, currentUserId: currentUserId);
  }

  Future<({List<ConversationModel> items, String? nextCursor, bool hasMore})>
      getConversations({
    String? cursor,
    int limit = 20,
    String? currentUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/messaging/conversations',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final itemsRaw = data['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map(
          (e) => ConversationModel.fromJson(
            e as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();

    return (
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<ConversationModel> getConversationById(
    String conversationId, {
    String? currentUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/messaging/conversations/$conversationId',
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return ConversationModel.fromJson(data, currentUserId: currentUserId);
  }

  Future<({List<MessageModel> items, String? nextCursor, bool hasMore})>
      getMessages(
    String conversationId, {
    String? cursor,
    int limit = 30,
    String? currentUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/messaging/conversations/$conversationId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final itemsRaw = data['items'] as List<dynamic>? ?? [];
    final items = itemsRaw
        .map(
          (e) => MessageModel.fromJson(
            e as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();

    return (
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<MessageModel> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String content,
    String? currentUserId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/messaging/conversations/$conversationId/messages',
      data: {
        'clientMessageId': clientMessageId,
        'content': content,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return MessageModel.fromJson(data, currentUserId: currentUserId);
  }

  Future<void> markAsRead(String conversationId) async {
    await _dio.post<Map<String, dynamic>>(
      '/messaging/conversations/$conversationId/read',
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _dio.delete<Map<String, dynamic>>('/messaging/messages/$messageId');
  }

  Future<void> reportConversation(
    String conversationId, {
    required String reason,
    String? description,
    String? messageId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/messaging/conversations/$conversationId/report',
      data: {
        'reason': reason,
        if (description != null) 'description': description,
        if (messageId != null) 'messageId': messageId,
      },
    );
  }

  Future<void> blockUser(String userId) async {
    await _dio.post<Map<String, dynamic>>(
      '/messaging/blocks',
      data: {'userId': userId},
    );
  }

  Future<void> unblockUser(String userId) async {
    await _dio.delete<Map<String, dynamic>>('/messaging/blocks/$userId');
  }

  Future<bool> getPresence(String userId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/messaging/presence/$userId');
    final data = response.data?['data'] as Map<String, dynamic>?;
    return data?['status'] == 'online';
  }
}
