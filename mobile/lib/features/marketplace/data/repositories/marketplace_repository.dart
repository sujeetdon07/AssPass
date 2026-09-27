import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/marketplace_listing_entity.dart';
import '../models/marketplace_listing_model.dart';

/// Provider for [MarketplaceRepository].
final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MarketplaceRepository(dio);
});

/// Client repository handling all Marketplace API interactions.
class MarketplaceRepository {
  const MarketplaceRepository(this._dio);

  final Dio _dio;

  /// Fetch paginated marketplace listings with search, filters, and optional radius.
  Future<MarketplaceListingPageModel> getListings({
    String? query,
    String? category,
    String? condition,
    double? minPrice,
    double? maxPrice,
    String? locality,
    String? city,
    int? radius,
    double? latitude,
    double? longitude,
    String? sortBy,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/marketplace/listings',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (category != null && category.isNotEmpty) 'category': category,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (locality != null && locality.isNotEmpty) 'locality': locality,
        if (city != null && city.isNotEmpty) 'city': city,
        if (radius != null) 'radius': radius,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (sortBy != null) 'sortBy': sortBy,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingPageModel.fromJson(data);
  }

  /// Fetch current user's listings by status.
  Future<MarketplaceListingPageModel> getMyListings({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/marketplace/listings/me',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingPageModel.fromJson(data);
  }

  /// Fetch current user's favorite listings.
  Future<MarketplaceListingPageModel> getFavorites({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/marketplace/favorites',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingPageModel.fromJson(data);
  }

  /// Retrieve single listing details by ID.
  Future<MarketplaceListingEntity> getListingById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/marketplace/listings/$id',
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingModel.fromJson(data).toEntity();
  }

  /// Create a new marketplace listing.
  Future<MarketplaceListingEntity> createListing({
    required String title,
    required String description,
    required String category,
    required double price,
    String currency = 'INR',
    required String condition,
    String? locality,
    String? city,
    String? state,
    List<Map<String, dynamic>>? images,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/marketplace/listings',
      data: {
        'title': title,
        'description': description,
        'category': category,
        'price': price,
        'currency': currency,
        'condition': condition,
        if (locality != null) 'locality': locality,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (images != null) 'images': images,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingModel.fromJson(data).toEntity();
  }

  /// Update an existing listing (owner only).
  Future<MarketplaceListingEntity> updateListing(
    String id, {
    String? title,
    String? description,
    String? category,
    double? price,
    String? condition,
    String? locality,
    String? city,
    String? state,
    List<Map<String, dynamic>>? images,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/marketplace/listings/$id',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (price != null) 'price': price,
        if (condition != null) 'condition': condition,
        if (locality != null) 'locality': locality,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (images != null) 'images': images,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingModel.fromJson(data).toEntity();
  }

  /// Update listing lifecycle status (active, sold, archived).
  Future<MarketplaceListingEntity> updateListingStatus(
    String id,
    String status,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/marketplace/listings/$id/status',
      data: {'status': status},
    );

    final data = response.data?['data'] as Map<String, dynamic>? ?? {};
    return MarketplaceListingModel.fromJson(data).toEntity();
  }

  /// Delete a listing (owner only, soft delete).
  Future<void> deleteListing(String id) async {
    await _dio.delete<void>('/marketplace/listings/$id');
  }

  /// Favorite a listing.
  Future<void> favoriteListing(String id) async {
    await _dio.post<Map<String, dynamic>>('/marketplace/listings/$id/favorite');
  }

  /// Unfavorite a listing.
  Future<void> unfavoriteListing(String id) async {
    await _dio
        .delete<Map<String, dynamic>>('/marketplace/listings/$id/favorite');
  }

  /// Report a listing for safety review.
  Future<void> reportListing(
    String id, {
    required String reason,
    String? details,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/marketplace/listings/$id/report',
      data: {
        'reason': reason,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
  }
}
