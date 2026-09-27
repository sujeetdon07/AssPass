import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';

class LocalitySuggestion {
  const LocalitySuggestion({
    required this.id,
    required this.countryCode,
    required this.state,
    required this.district,
    required this.city,
    required this.locality,
    this.postalCode,
    this.popularNeighborhoods = const [],
  });

  final String id;
  final String countryCode;
  final String state;
  final String district;
  final String city;
  final String locality;
  final String? postalCode;
  final List<String> popularNeighborhoods;

  factory LocalitySuggestion.fromJson(Map<String, dynamic> json) {
    return LocalitySuggestion(
      id: json['id'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? 'IN',
      state: json['state'] as String? ?? '',
      district: json['district'] as String? ?? '',
      city: json['city'] as String? ?? '',
      locality: json['locality'] as String? ?? '',
      postalCode: json['postalCode'] as String?,
      popularNeighborhoods: (json['popularNeighborhoods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String get displayName => '$locality, $city';
}

class OnboardingRepository {
  const OnboardingRepository(this._dio);

  final Dio _dio;

  /// Submit onboarding profile details and locality to backend.
  Future<UserEntity> completeOnboarding({
    required String displayName,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
    String? avatarUrl,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me/onboarding',
      data: {
        'displayName': displayName,
        if (countryCode != null) 'countryCode': countryCode,
        if (state != null) 'state': state,
        if (district != null) 'district': district,
        if (city != null) 'city': city,
        if (locality != null) 'locality': locality,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return UserModel.fromJson(data);
  }

  /// Search curated localities with backend and live Nominatim fallback.
  Future<List<LocalitySuggestion>> searchLocalities(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getPopularLocalities();
    }

    // 1. Try backend search endpoint
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/localities/search',
        queryParameters: {'query': trimmed, 'limit': 15},
      );

      final raw = response.data;
      if (raw != null) {
        final dynamic listData = raw['data'] ?? raw;
        if (listData is List && listData.isNotEmpty) {
          return listData
              .map(
                (item) =>
                    LocalitySuggestion.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (_) {
      // Backend unavailable or error; proceed to direct geocoding fallback
    }

    // 2. Direct client fallback to OpenStreetMap Nominatim
    return _directNominatimSearch(trimmed);
  }

  /// Reverse geocode GPS coordinates to a LocalitySuggestion.
  Future<LocalitySuggestion?> fetchCurrentLocationLocality({
    required double lat,
    required double lng,
  }) async {
    // 1. Try backend reverse geocode endpoint
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/localities/reverse',
        queryParameters: {'lat': lat, 'lon': lng},
      );

      final raw = response.data;
      if (raw != null) {
        final dynamic itemData = raw['data'] ?? raw;
        if (itemData is Map<String, dynamic> && itemData.isNotEmpty) {
          return LocalitySuggestion.fromJson(itemData);
        }
      }
    } catch (_) {
      // Backend unavailable or error; proceed to direct geocoding fallback
    }

    // 2. Direct client fallback to OpenStreetMap Nominatim
    return _directNominatimReverse(lat, lng);
  }

  /// Fetch popular metro localities for quick selection.
  Future<List<LocalitySuggestion>> getPopularLocalities() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/localities/popular',
        queryParameters: {'limit': 10},
      );

      final raw = response.data;
      if (raw != null) {
        final dynamic listData = raw['data'] ?? raw;
        if (listData is List) {
          return listData
              .map(
                (item) =>
                    LocalitySuggestion.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Direct Nominatim search fallback if backend is unreachable or returns empty.
  Future<List<LocalitySuggestion>> _directNominatimSearch(String query) async {
    try {
      final directDio = Dio(
        BaseOptions(
          headers: {'User-Agent': 'Aaspaas-Mobile/1.0 (contact@aaspaas.in)'},
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&countrycodes=in&limit=15';
      final res = await directDio.get<List<dynamic>>(url);
      final list = res.data;
      if (list == null || list.isEmpty) {
        return const [];
      }

      final results = <LocalitySuggestion>[];
      final seen = <String>{};

      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final item = _parseNominatimMap(raw);
        if (item != null) {
          final key = '${item.locality.toLowerCase()}|${item.city.toLowerCase()}';
          if (!seen.contains(key)) {
            seen.add(key);
            results.push(item);
          }
        }
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  /// Direct Nominatim reverse fallback if backend is unreachable.
  Future<LocalitySuggestion?> _directNominatimReverse(
    double lat,
    double lng,
  ) async {
    try {
      final directDio = Dio(
        BaseOptions(
          headers: {'User-Agent': 'Aaspaas-Mobile/1.0 (contact@aaspaas.in)'},
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1';
      final res = await directDio.get<Map<String, dynamic>>(url);
      final raw = res.data;
      if (raw == null) return null;
      return _parseNominatimMap(raw);
    } catch (_) {
      return null;
    }
  }

  LocalitySuggestion? _parseNominatimMap(Map<String, dynamic> raw) {
    final addr = (raw['address'] as Map<String, dynamic>?) ?? {};
    final city = addr['city'] as String? ??
        addr['town'] as String? ??
        addr['municipality'] as String? ??
        addr['village'] as String? ??
        addr['county'] as String? ??
        addr['state_district'] as String? ??
        '';

    final state = addr['state'] as String? ??
        addr['state_district'] as String? ??
        '';
    final district = addr['state_district'] as String? ??
        addr['county'] as String? ??
        city;

    final name = raw['name'] as String?;
    final residential = addr['residential'] as String?;
    final suburb = addr['suburb'] as String?;
    final neighbourhood = addr['neighbourhood'] as String?;
    final quarter = addr['quarter'] as String?;
    final road = addr['road'] as String?;

    String locality = name ??
        residential ??
        suburb ??
        neighbourhood ??
        quarter ??
        road ??
        city;

    if (locality.isEmpty && city.isEmpty) {
      return null;
    }
    if (locality.isEmpty) {
      locality = city;
    }

    final id = 'osm-${raw['osm_id'] ?? raw['place_id'] ?? locality.hashCode}';

    return LocalitySuggestion(
      id: id,
      countryCode:
          (addr['country_code'] as String? ?? 'in').toUpperCase(),
      state: state,
      district: district,
      city: city.isNotEmpty ? city : locality,
      locality: locality,
      postalCode: addr['postcode'] as String?,
    );
  }
}

extension _ListPush<T> on List<T> {
  void push(T element) => add(element);
}

/// Riverpod provider for [OnboardingRepository].
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return OnboardingRepository(dio);
});
