import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_filter.dart';
import '../models/service_listing_model.dart';

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ServicesRepository(dio);
});

class ServicesRepository {
  const ServicesRepository(this._dio);

  final Dio _dio;

  Future<PaginatedServicesModel> getServices({
    String? query,
    ServiceCategory? category,
    PricingModel? pricingModel,
    String? locality,
    String? city,
    double? latitude,
    double? longitude,
    double? radius,
    ServiceSortOption? sortBy,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      if (category != null) 'category': category.value,
      if (pricingModel != null) 'pricingModel': pricingModel.value,
      if (locality != null && locality.trim().isNotEmpty)
        'locality': locality.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radius != null) 'radius': radius,
      if (sortBy != null) 'sortBy': sortBy.value,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/services',
      queryParameters: queryParams,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return PaginatedServicesModel.fromJson(data);
  }

  Future<ServiceListingModel> getServiceById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/services/$id');
    final data = response.data!['data'] as Map<String, dynamic>;
    return ServiceListingModel.fromJson(data);
  }

  Future<ServiceListingModel> createService(
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/services', data: payload);
    final data = response.data!['data'] as Map<String, dynamic>;
    return ServiceListingModel.fromJson(data);
  }

  Future<ServiceListingModel> updateService(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _dio.patch<Map<String, dynamic>>('/services/$id', data: payload);
    final data = response.data!['data'] as Map<String, dynamic>;
    return ServiceListingModel.fromJson(data);
  }

  Future<ServiceListingModel> updateServiceStatus(
    String id,
    ServiceStatus status,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/services/$id/status',
      data: {'status': status.value},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return ServiceListingModel.fromJson(data);
  }

  Future<void> deleteService(String id) async {
    await _dio.delete<void>('/services/$id');
  }

  Future<PaginatedServicesModel> getMyServices({
    ServiceStatus? status,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      if (status != null) 'status': status.value,
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    };

    final response = await _dio.get<Map<String, dynamic>>(
      '/services/me',
      queryParameters: queryParams,
    );

    final data = response.data!['data'] as Map<String, dynamic>;
    return PaginatedServicesModel.fromJson(data);
  }

  Future<({bool isFavorited, int favoriteCount})> toggleFavorite(
    String id,
    bool favorite,
  ) async {
    Response<Map<String, dynamic>> response;
    if (favorite) {
      response =
          await _dio.post<Map<String, dynamic>>('/services/$id/favorite');
    } else {
      response =
          await _dio.delete<Map<String, dynamic>>('/services/$id/favorite');
    }

    final data = response.data!['data'] as Map<String, dynamic>;
    return (
      isFavorited: data['isFavorited'] as bool? ?? favorite,
      favoriteCount: (data['favoriteCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> reportService(
    String id,
    String reason,
    String? details,
  ) async {
    await _dio.post<Map<String, dynamic>>(
      '/services/$id/report',
      data: {
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }
}
