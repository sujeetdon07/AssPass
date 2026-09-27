import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_entity.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

class OtpRequestResult {
  const OtpRequestResult({
    required this.message,
    required this.maskedPhoneNumber,
    required this.cooldownSeconds,
    required this.expiresInSeconds,
    this.devOtp,
  });

  final String message;
  final String maskedPhoneNumber;
  final int cooldownSeconds;
  final int expiresInSeconds;
  final String? devOtp;
}

class AuthResult {
  const AuthResult({
    required this.user,
    required this.tokens,
  });

  final UserEntity user;
  final AuthTokensModel tokens;
}

/// Repository responsible for remote authentication API calls.
class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  /// Request a 6-digit OTP for the given phone number.
  Future<OtpRequestResult> requestOtp(String phoneNumber) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/request',
      data: {'phoneNumber': phoneNumber},
    );

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return OtpRequestResult(
      message: data['message'] as String? ?? 'Code sent.',
      maskedPhoneNumber: data['maskedPhoneNumber'] as String? ?? phoneNumber,
      cooldownSeconds: data['cooldownSeconds'] as int? ?? 60,
      expiresInSeconds: data['expiresInSeconds'] as int? ?? 300,
      devOtp: data['devOtp'] as String?,
    );
  }

  /// Verify 6-digit OTP and obtain tokens + user profile.
  Future<AuthResult> verifyOtp({
    required String phoneNumber,
    required String otp,
    Map<String, dynamic>? deviceMetadata,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      data: {
        'phoneNumber': phoneNumber,
        'otp': otp,
        if (deviceMetadata != null) 'deviceMetadata': deviceMetadata,
      },
    );

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final userJson = data['user'] as Map<String, dynamic>;
    final tokensJson = data['tokens'] as Map<String, dynamic>;

    return AuthResult(
      user: UserModel.fromJson(userJson),
      tokens: AuthTokensModel.fromJson(tokensJson),
    );
  }

  /// Refresh session credentials.
  Future<AuthTokensModel> refreshToken(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return AuthTokensModel.fromJson(data);
  }

  /// Revoke current session.
  Future<void> logout() async {
    try {
      await _dio.post<dynamic>('/auth/logout');
    } catch (_) {
      // Best effort remote revocation
    }
  }

  /// Fetch currently authenticated user profile from backend.
  Future<UserEntity> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return UserModel.fromJson(data);
  }

  /// Update user profile attributes on backend.
  Future<UserEntity> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? countryCode,
    String? state,
    String? district,
    String? city,
    String? locality,
    String? neighborhood,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/users/me/profile',
      data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (countryCode != null) 'countryCode': countryCode,
        if (state != null) 'state': state,
        if (district != null) 'district': district,
        if (city != null) 'city': city,
        if (locality != null) 'locality': locality,
        if (neighborhood != null) 'neighborhood': neighborhood,
      },
    );

    final raw = response.data!;
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    return UserModel.fromJson(data);
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});
