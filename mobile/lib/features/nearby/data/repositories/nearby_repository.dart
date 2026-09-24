import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../models/nearby_page_model.dart';

/// Provider for [NearbyRepository].
final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NearbyRepository(dio);
});

/// Client repository handling Nearby radius discovery API interactions.
class NearbyRepository {
  const NearbyRepository(this._dio);

  final Dio _dio;

  /// Discover nearby posts within a given radius from coordinates.
  Future<NearbyPageModel> getNearbyPosts({
    required double latitude,
    required double longitude,
    int radius = 5,
    int limit = 20,
    String? cursor,
    PostCategory? category,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/nearby/posts',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (category != null) 'category': category.value,
      },
    );

    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return NearbyPageModel.fromJson(data);
  }
}
