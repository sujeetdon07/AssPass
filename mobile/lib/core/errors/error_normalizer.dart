import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Normalizes Dio errors into typed [AppException] instances.
///
/// Call this from interceptors or catch blocks to ensure that no raw
/// Dio exceptions reach the presentation layer.
class ErrorNormalizer {
  ErrorNormalizer._();

  /// Converts a [DioException] to an [AppException].
  static AppException fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException();

      case DioExceptionType.connectionError:
        return const NetworkException();

      case DioExceptionType.badResponse:
        return _fromHttpStatusCode(
          error.response?.statusCode,
          error.response?.data,
        );

      case DioExceptionType.cancel:
        return const UnknownException(message: 'Request was cancelled.');

      case DioExceptionType.unknown:
        // Could be a connectivity issue wrapped as unknown.
        if (error.error != null &&
            error.error.toString().contains('SocketException')) {
          return const NetworkException();
        }
        return const UnknownException();

      case DioExceptionType.badCertificate:
        return const UnknownException(message: 'SSL certificate error.');
    }
  }

  /// Converts any exception (not just Dio) into an [AppException].
  static AppException fromException(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return fromDio(error);
    return const UnknownException();
  }

  static AppException _fromHttpStatusCode(int? statusCode, dynamic data) {
    // Try to extract a message from the response body.
    final message = _extractMessage(data);

    return switch (statusCode) {
      401 =>
        UnauthorizedException(message: message ?? 'Authentication required.'),
      403 => ForbiddenException(message: message ?? 'Permission denied.'),
      404 => NotFoundException(message: message ?? 'Resource not found.'),
      409 => ConflictException(message: message ?? 'Conflict.'),
      422 => ValidationException(message: message ?? 'Validation failed.'),
      final int code when code >= 500 => ServerException(
          message: message ?? 'Server error.',
          statusCode: statusCode,
        ),
      _ => UnknownException(message: message ?? 'Unexpected error.'),
    };
  }

  static String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      // NestJS default error shape: { "message": "..." }
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();

      // Custom Aaspaas error shape: { "error": { "message": "..." } }
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final innerMsg = error['message'];
        if (innerMsg is String) return innerMsg;
      }
    }
    return null;
  }
}
