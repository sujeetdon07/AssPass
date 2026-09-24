import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../feed/data/models/post_model.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../domain/entities/community_category.dart';
import '../../domain/entities/community_entity.dart';
import '../models/communities_page_model.dart';
import '../models/community_model.dart';

/// Provider for [CommunitiesRepository].
final communitiesRepositoryProvider = Provider<CommunitiesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CommunitiesRepository(dio);
});

/// Client repository handling all Community API interactions.
class CommunitiesRepository {
  const CommunitiesRepository(this._dio);

  final Dio _dio;

  /// Fetch paginated list of communities with filters.
  Future<CommunitiesPageModel> getCommunities({
    String? cursor,
    int limit = 20,
    String? category,
    String? search,
    String scope = 'all',
    bool? joinedOnly,
    String? locality,
    String? city,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/communities',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'scope': scope,
        if (joinedOnly != null) 'joinedOnly': joinedOnly.toString(),
        if (locality != null && locality.isNotEmpty) 'locality': locality,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunitiesPageModel.fromJson(data);
  }

  /// Retrieve single community details by ID or slug.
  Future<CommunityEntity> getCommunityById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/communities/$id',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunityModel.fromJson(data).toEntity();
  }

  /// Create a new community.
  Future<CommunityEntity> createCommunity({
    required String name,
    required String description,
    required CommunityCategory category,
    String visibility = 'public',
    String? locality,
    String? neighborhood,
    String? city,
    String? state,
    String? countryCode,
    String? coverImageUrl,
    String? avatarUrl,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/communities',
      data: {
        'name': name,
        'description': description,
        'category': category.value,
        'visibility': visibility,
        if (locality != null && locality.isNotEmpty) 'locality': locality,
        if (neighborhood != null && neighborhood.isNotEmpty)
          'neighborhood': neighborhood,
        if (city != null && city.isNotEmpty) 'city': city,
        if (state != null && state.isNotEmpty) 'state': state,
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode,
        if (coverImageUrl != null && coverImageUrl.isNotEmpty)
          'coverImageUrl': coverImageUrl,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunityModel.fromJson(data).toEntity();
  }

  /// Update an existing community (owner or moderator only).
  Future<CommunityEntity> updateCommunity({
    required String id,
    String? name,
    String? description,
    CommunityCategory? category,
    String? visibility,
    String? locality,
    String? neighborhood,
    String? coverImageUrl,
    String? avatarUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/communities/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category.value,
        if (visibility != null) 'visibility': visibility,
        if (locality != null) 'locality': locality,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunityModel.fromJson(data).toEntity();
  }

  /// Join a community.
  Future<CommunityEntity> joinCommunity(String id) async {
    await _dio.post<Map<String, dynamic>>(
      '/communities/$id/join',
    );
    return getCommunityById(id);
  }

  /// Leave a community.
  Future<CommunityEntity> leaveCommunity(String id) async {
    await _dio.delete<Map<String, dynamic>>(
      '/communities/$id/membership',
    );
    return getCommunityById(id);
  }

  /// Get paginated members of a community.
  Future<CommunityMembersPageModel> getCommunityMembers({
    required String id,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/communities/$id/members',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunityMembersPageModel.fromJson(data);
  }

  /// Get paginated posts within a community feed.
  Future<CommunityPostsPageModel> getCommunityPosts({
    required String id,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/communities/$id/posts',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return CommunityPostsPageModel.fromJson(data);
  }

  /// Create a post inside a community.
  Future<PostEntity> createCommunityPost({
    required String id,
    required String content,
    required PostCategory category,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/communities/$id/posts',
      data: {
        'content': content,
        'category': category.value,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return PostModel.fromJson(data).toEntity();
  }

  /// Report a community for safety review.
  Future<void> reportCommunity({
    required String id,
    required String reason,
    String? details,
  }) async {
    await _dio.post<void>(
      '/communities/$id/report',
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}
