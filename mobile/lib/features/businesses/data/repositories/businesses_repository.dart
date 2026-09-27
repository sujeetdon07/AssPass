import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/business_category.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/business_filter.dart';
import '../models/business_model.dart';

final businessesRepositoryProvider = Provider<BusinessesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return BusinessesRepository(dio);
});

class BusinessesRepository {
  const BusinessesRepository(this._dio);

  final Dio _dio;

  Future<PaginatedBusinessesModel> getBusinesses({
    String? query,
    BusinessCategory? category,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    double? radius,
    bool? openNow,
    BusinessSortOption? sortBy,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (category != null) 'category': category.value,
      if (locality != null && locality.trim().isNotEmpty)
        'locality': locality.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radius != null) 'radius': radius,
      if (openNow == true) 'openNow': true,
      if (sortBy != null) 'sortBy': sortBy.value,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/businesses',
      queryParameters: queryParams,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return PaginatedBusinessesModel.fromJson(data);
  }

  Future<BusinessModel> getBusinessById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/businesses/$id');
    final data = response.data!['data'] as Map<String, dynamic>;
    return BusinessModel.fromJson(data);
  }

  Future<BusinessModel> createBusiness(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/businesses', data: payload);
    final data = response.data!['data'] as Map<String, dynamic>;
    return BusinessModel.fromJson(data);
  }

  Future<BusinessModel> updateBusiness(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/businesses/$id',
      data: payload,
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return BusinessModel.fromJson(data);
  }

  Future<BusinessModel> updateBusinessStatus(
    String id,
    BusinessStatus status,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/businesses/$id/status',
      data: {'status': status.value},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return BusinessModel.fromJson(data);
  }

  Future<void> deleteBusiness(String id) async {
    await _dio.delete<void>('/businesses/$id');
  }

  Future<PaginatedBusinessesModel> getMyBusinesses({
    BusinessStatus? status,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null) 'status': status.value,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/businesses/me',
      queryParameters: queryParams,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return PaginatedBusinessesModel.fromJson(data);
  }

  Future<({bool isFavorited, int favoriteCount})> toggleFavorite(
    String id,
    bool favorite,
  ) async {
    Response<Map<String, dynamic>> response;
    if (favorite) {
      response =
          await _dio.post<Map<String, dynamic>>('/businesses/$id/favorite');
    } else {
      response =
          await _dio.delete<Map<String, dynamic>>('/businesses/$id/favorite');
    }

    final data = response.data!['data'] as Map<String, dynamic>;
    return (
      isFavorited: data['isFavorited'] as bool? ?? favorite,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> reportBusiness(
    String id,
    String reason,
    String? details,
  ) async {
    await _dio.post<Map<String, dynamic>>(
      '/businesses/$id/report',
      data: {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }
}
