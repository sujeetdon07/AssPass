import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';
import '../errors/error_normalizer.dart';
import '../storage/secure_storage_service.dart';

/// Riverpod provider for the configured [Dio] HTTP client.
///
/// Inject this provider wherever an API client is needed instead of
/// creating Dio instances directly. This allows test overrides.
final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Attach interceptors in order:
  dio.interceptors.addAll([
    AuthInterceptor(
      secureStorage: secureStorage,
      dio: dio,
    ),
    _LoggingInterceptor(), // Development-only request/response logs.
    _ErrorNormalizationInterceptor(), // Maps errors to AppException.
  ]);

  return dio;
});

// ── Auth Interceptor ──────────────────────────────────────────────────────────

/// Attaches the JWT access token to outgoing requests and handles automatic
/// 401 token refresh using [QueuedInterceptor] to avoid concurrent refresh requests.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.dio,
    this.onUnauthenticated,
  });

  final SecureStorageService secureStorage;
  final Dio dio;
  final VoidCallback? onUnauthenticated;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only attempt refresh on 401 Unauthorized
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    // Prevent infinite loops on auth endpoints
    if (path.contains('/auth/refresh') ||
        path.contains('/auth/otp/') ||
        path.contains('/auth/login')) {
      return handler.next(err);
    }

    final refreshToken = await secureStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await secureStorage.clearAuthTokens();
      onUnauthenticated?.call();
      return handler.next(err);
    }

    try {
      // Create isolated Dio instance to avoid interceptor recursion
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
        ),
      );

      final response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final body = response.data!;
        final data = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body;

        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await secureStorage.saveAccessToken(newAccessToken);
          await secureStorage.saveRefreshToken(newRefreshToken);

          // Retry the original request with the new access token
          final requestOptions = err.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          final clonedResponse = await dio.fetch<dynamic>(requestOptions);
          return handler.resolve(clonedResponse);
        }
      }

      await secureStorage.clearAuthTokens();
      onUnauthenticated?.call();
      return handler.next(err);
    } catch (_) {
      await secureStorage.clearAuthTokens();
      onUnauthenticated?.call();
      return handler.next(err);
    }
  }
}

// ── Logging Interceptor ───────────────────────────────────────────────────────

/// Logs requests and responses in development mode only.
///
/// NEVER logs:
/// - Authorization header values
/// - Passwords
/// - OTPs
/// - Sensitive response fields
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (AppConfig.isDebugMode) {
      // Sanitize headers before logging — never log auth tokens.
      final safeHeaders = Map<String, dynamic>.from(options.headers)
        ..remove('Authorization');
      if (kDebugMode) {
        // ignore: avoid_print
        print('[API] → ${options.method} ${options.uri} headers=$safeHeaders');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (AppConfig.isDebugMode && kDebugMode) {
      // ignore: avoid_print
      print('[API] ← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (AppConfig.isDebugMode && kDebugMode) {
      // ignore: avoid_print
      print(
        '[API] ✗ ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}',
      );
    }
    handler.next(err);
  }
}

// ── Error Normalization Interceptor ───────────────────────────────────────────

/// Converts [DioException] into typed [AppException] instances.
///
/// This must be the last interceptor so it can catch errors from all
/// previous interceptors.
class _ErrorNormalizationInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final normalized = ErrorNormalizer.fromDio(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: normalized,
        type: err.type,
        response: err.response,
        message: normalized.message,
      ),
    );
  }
}

/// Extension to extract the typed [AppException] from a [DioException].
extension DioExceptionExtension on DioException {
  AppException? get appException =>
      error is AppException ? error as AppException : null;
}
