import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized application configuration.
///
/// Reads environment variables from the loaded .env file.
/// Never hardcode secrets or environment-specific values elsewhere.
class AppConfig {
  AppConfig._(); // Prevent instantiation.

  /// The backend API base URL.
  /// Example: http://10.0.2.2:3000/api/v1
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000/api/v1';

  /// The current runtime environment name.
  /// Values: development | staging | production
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';

  /// Whether the app is running in development mode.
  static bool get isDevelopment => environment == 'development';

  /// Whether the app is running in staging mode.
  static bool get isStaging => environment == 'staging';

  /// Whether the app is running in production mode.
  static bool get isProduction => environment == 'production';

  /// Whether development-only features (logs, debug banner) are enabled.
  static bool get isDebugMode => isDevelopment || isStaging;
}
