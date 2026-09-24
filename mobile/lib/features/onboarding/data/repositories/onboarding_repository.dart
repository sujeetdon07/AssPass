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

  /// Search curated localities for autocomplete.
  Future<List<LocalitySuggestion>> searchLocalities(String query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/localities/search',
        queryParameters: {'query': query, 'limit': 15},
      );

      final raw = response.data!;
      final dynamic listData = raw['data'];
      if (listData is List) {
        return listData
            .map(
              (item) =>
                  LocalitySuggestion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Fetch popular metro localities for quick selection.
  Future<List<LocalitySuggestion>> getPopularLocalities() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/localities/popular',
        queryParameters: {'limit': 10},
      );

      final raw = response.data!;
      final dynamic listData = raw['data'];
      if (listData is List) {
        return listData
            .map(
              (item) =>
                  LocalitySuggestion.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Riverpod provider for [OnboardingRepository].
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return OnboardingRepository(dio);
});
