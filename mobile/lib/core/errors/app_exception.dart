/// Base class for all application-level exceptions.
///
/// Every exception that propagates to the UI should be one of these types
/// or a subclass of one of these types. Never let raw Dio/HTTP exceptions
/// reach the presentation layer.
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    this.statusCode,
  });

  /// Human-readable error message. Do not show this directly in the UI;
  /// map it to a localized string in the presentation layer.
  final String message;

  /// HTTP status code, if applicable.
  final int? statusCode;

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode)';
}

// ── Network exceptions ────────────────────────────────────────────────────────

/// A general network error (no connectivity, DNS failure, etc.).
final class NetworkException extends AppException {
  const NetworkException({super.message = 'No internet connection.'});
}

/// The request timed out.
final class TimeoutException extends AppException {
  const TimeoutException({super.message = 'The request timed out.'});
}

// ── HTTP / Server exceptions ──────────────────────────────────────────────────

/// 401 — The user is not authenticated.
final class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Authentication required.',
    super.statusCode = 401,
  });
}

/// 403 — The user is authenticated but does not have permission.
final class ForbiddenException extends AppException {
  const ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.statusCode = 403,
  });
}

/// 404 — The requested resource was not found.
final class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'The requested resource was not found.',
    super.statusCode = 404,
  });
}

/// 409 — Resource conflict.
final class ConflictException extends AppException {
  const ConflictException({
    super.message = 'A conflict occurred.',
    super.statusCode = 409,
  });
}

/// 422 — Validation failure.
final class ValidationException extends AppException {
  const ValidationException({
    super.message = 'Validation failed.',
    super.statusCode = 422,
    this.fieldErrors = const {},
  });

  /// Field-level validation errors returned from the server.
  final Map<String, List<String>> fieldErrors;
}

/// 5xx — A server-side error occurred.
final class ServerException extends AppException {
  const ServerException({
    super.message = 'An unexpected server error occurred.',
    super.statusCode = 500,
  });
}

/// An unexpected or unknown error.
final class UnknownException extends AppException {
  const UnknownException({super.message = 'An unexpected error occurred.'});
}
