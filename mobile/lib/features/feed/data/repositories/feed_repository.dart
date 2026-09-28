import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/post_entity.dart';
import '../models/comment_model.dart';
import '../models/feed_page_model.dart';
import '../models/post_model.dart';

/// Provider for [FeedRepository].
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return FeedRepository(dio);
});

/// Client repository handling all Community Feed API interactions.
class FeedRepository {
  const FeedRepository(this._dio);

  final Dio _dio;

  /// Fetch paginated feed posts with optional cursor, category, and scope.
  Future<FeedPageModel> getFeed({
    String? cursor,
    int limit = 20,
    String? category,
    String scope = 'local',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/feed/posts',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        'scope': scope,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return FeedPageModel.fromJson(data);
  }

  /// Retrieve single post details by ID.
  Future<PostEntity> getPostById(String postId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/feed/posts/$postId',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return PostModel.fromJson(data).toEntity();
  }

  /// Create a new post in the user's community feed.
  Future<PostEntity> createPost({
    required String content,
    required PostCategory category,
    List<PostMention>? mentions,
    String? locality,
    String? neighborhood,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/feed/posts',
      data: {
        'content': content,
        'category': category.value,
        'mentions': mentions?.map((m) => m.toJson()).toList() ?? [],
        if (locality != null) 'locality': locality,
        if (neighborhood != null) 'neighborhood': neighborhood,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return PostModel.fromJson(data).toEntity();
  }

  /// Update an existing post authored by the current user.
  Future<PostEntity> updatePost({
    required String postId,
    required String content,
    PostCategory? category,
    List<PostMention>? mentions,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/feed/posts/$postId',
      data: {
        'content': content,
        if (category != null) 'category': category.value,
        if (mentions != null)
          'mentions': mentions.map((m) => m.toJson()).toList(),
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return PostModel.fromJson(data).toEntity();
  }

  /// Soft delete a post authored by the current user.
  Future<void> deletePost(String postId) async {
    await _dio.delete<void>('/feed/posts/$postId');
  }

  /// Like a post.
  Future<Map<String, dynamic>> likePost(String postId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/feed/posts/$postId/like',
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        {'liked': true, 'likeCount': 1};
  }

  /// Remove like from a post.
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/feed/posts/$postId/like',
    );
    return response.data?['data'] as Map<String, dynamic>? ??
        {'liked': false, 'likeCount': 0};
  }

  /// List paginated comments for a post.
  Future<CommentsPageModel> getComments({
    required String postId,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/feed/posts/$postId/comments',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommentsPageModel.fromJson(data);
  }

  /// Post a new comment on a post.
  Future<CommentEntity> createComment({
    required String postId,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/feed/posts/$postId/comments',
      data: {'content': content},
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommentModel.fromJson(data).toEntity();
  }

  /// Delete a comment authored by the current user.
  Future<void> deleteComment(String commentId) async {
    await _dio.delete<void>('/feed/comments/$commentId');
  }

  /// Report a post for safety review.
  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    await _dio.post<void>(
      '/feed/posts/$postId/report',
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }

  /// Report a comment for safety review.
  Future<void> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    await _dio.post<void>(
      '/feed/comments/$commentId/report',
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}
