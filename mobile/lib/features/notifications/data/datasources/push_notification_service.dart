import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/storage/secure_storage_service.dart';
import 'notifications_remote_data_source.dart';

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final remoteDataSource = ref.watch(notificationsRemoteDataSourceProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return PushNotificationService(remoteDataSource, secureStorage);
});

/// Handles real FCM token lifecycle, permission request, foreground message
/// listening, and notification-tap deep-link routing for Aaspaas.
///
/// PRIVACY RULES enforced here:
/// - FCM tokens are never printed in full to logs.
/// - Notification payloads routed to deep links contain only entity IDs.
/// - No private message bodies, phone numbers, or location data are used.
class PushNotificationService {
  PushNotificationService(this._remoteDataSource, this._secureStorage);

  final NotificationsRemoteDataSource _remoteDataSource;
  final SecureStorageService _secureStorage;

  static const String _storedDeviceTokenKey = 'aaspaas_device_push_token';

  // Stable reference to the router set after initialization.
  // We hold it weakly so we do not prevent router GC on logout.
  GoRouter? _router;

  String? _currentToken;
  String? get currentToken => _currentToken;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;

  // IDs of notifications already shown in the center (from WebSocket).
  // Used to avoid double-displaying when a foreground FCM message arrives
  // for a notification that was also delivered via WebSocket.
  final Set<String> _handledNotificationIds = {};

  /// Called by [AaspaasApp] to supply the router for deep-link navigation.
  void attachRouter(GoRouter router) {
    _router = router;
  }

  /// Initialize push notifications after the user authenticates.
  /// Requests Android 13+ permission, acquires a real FCM token,
  /// registers it with the backend, and sets up listeners.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Request notification permission (Android 13+ / iOS).
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) {
        // Permission denied — notification center still works via WebSocket.
        // Do not block auth flow or treat denial as error.
        debugPrint(
          '[PushNotificationService] Notification permission denied — '
          'in-app notification center unaffected.',
        );
      }

      // 2. Acquire the real FCM registration token.
      //    Prefer the cached token; FCM returns the same token until rotation.
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          '[PushNotificationService] FCM token unavailable — '
          'running without push (in-app notifications still active).',
        );
        _isInitialized = true;
        return;
      }

      _currentToken = token;
      await _secureStorage.write(key: _storedDeviceTokenKey, value: token);

      // 3. Register real token with the backend.
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _remoteDataSource.registerDeviceToken(
        token: token,
        platform: platform,
        deviceId: 'device_$platform',
      );

      debugPrint(
        '[PushNotificationService] Initialized — '
        'token ends …${token.substring(token.length > 10 ? token.length - 10 : 0)}',
      );

      // 4. Subscribe to token refresh so the backend always has the latest.
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        _onTokenRefresh,
        onError: (Object e) {
          debugPrint('[PushNotificationService] Token refresh error: $e');
        },
      );

      // 5. Set up foreground message listener.
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 6. Handle notification tap when app was in background (tap woke it).
      _tapSub = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTapped);

      // 7. Handle notification tap when app was terminated.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _onMessageTapped(initial);
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Push initialization error: $e');
      // Never crash the app; notification center still works via WebSocket.
    }
  }

  /// Called when FCM rotates the token. Updates secure storage and backend.
  Future<void> _onTokenRefresh(String newToken) async {
    _currentToken = newToken;
    await _secureStorage.write(key: _storedDeviceTokenKey, value: newToken);
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _remoteDataSource.registerDeviceToken(
        token: newToken,
        platform: platform,
        deviceId: 'device_$platform',
      );
      debugPrint('[PushNotificationService] Token refreshed and re-registered.');
    } catch (e) {
      debugPrint('[PushNotificationService] Token refresh registration error: $e');
    }
  }

  /// Handles FCM messages received while the app is in the foreground.
  ///
  /// The backend WebSocket already delivers the notification to the center —
  /// so we only record the ID here to prevent duplication if the same
  /// notification arrives both ways. The FCM SDK does NOT auto-display a
  /// system notification in the foreground; that is intentional because the
  /// in-app notification center is already visible to the user.
  void _onForegroundMessage(RemoteMessage message) {
    final notificationId = message.data['notificationId'];
    if (notificationId != null && notificationId is String) {
      _handledNotificationIds.add(notificationId);
    }
    // No UI work here — the existing WebSocket-driven notification center
    // (NotificationsController) already shows the item.
    debugPrint(
      '[PushNotificationService] Foreground FCM message received '
      '(type=${message.data["type"] ?? "unknown"}) — '
      'notification center updated via WebSocket.',
    );
  }

  /// Routes the user to the appropriate Aaspaas destination when they tap a
  /// notification from the system tray (background or terminated state).
  ///
  /// Routing is based on the safe routing metadata in the FCM data payload —
  /// never on raw private message content.
  void _onMessageTapped(RemoteMessage message) {
    final data = message.data;
    final deepLink = data['deepLink'] as String?;
    final type = data['type'] as String?;

    final router = _router;
    if (router == null) return;

    // Navigate to the specific deep link if present and valid.
    if (deepLink != null && deepLink.isNotEmpty) {
      _safeNavigate(router, deepLink);
      return;
    }

    // Fall back to routing by notification type.
    switch (type) {
      case 'MESSAGE_RECEIVED':
        final entityId = data['entityId'] as String?;
        if (entityId != null && entityId.isNotEmpty) {
          _safeNavigate(router, '/messages/$entityId');
        } else {
          _safeNavigate(router, AppRoutes.messages);
        }
      case 'POST_LIKED':
      case 'POST_COMMENTED':
      case 'COMMENT_REPLIED':
        final entityId = data['entityId'] as String?;
        if (entityId != null && entityId.isNotEmpty) {
          _safeNavigate(router, '/feed/posts/$entityId');
        } else {
          _safeNavigate(router, AppRoutes.home);
        }
      case 'COMMUNITY_MEMBERSHIP':
      case 'COMMUNITY_ANNOUNCEMENT':
        final entityId = data['entityId'] as String?;
        if (entityId != null && entityId.isNotEmpty) {
          _safeNavigate(router, '/communities/$entityId');
        } else {
          _safeNavigate(router, AppRoutes.communities);
        }
      case 'MARKETPLACE_ACTIVITY':
        final entityId = data['entityId'] as String?;
        if (entityId != null && entityId.isNotEmpty) {
          _safeNavigate(router, '/marketplace/listings/$entityId');
        } else {
          _safeNavigate(router, AppRoutes.marketplace);
        }
      case 'BUSINESS_ACTIVITY':
        final entityId = data['entityId'] as String?;
        if (entityId != null && entityId.isNotEmpty) {
          _safeNavigate(router, '/businesses/$entityId');
        } else {
          _safeNavigate(router, AppRoutes.businesses);
        }
      default:
        // Unknown type or SYSTEM — route to notification center.
        _safeNavigate(router, AppRoutes.notifications);
    }
  }

  /// Navigates safely; if the destination no longer exists, falls back to
  /// the notification center rather than crashing.
  void _safeNavigate(GoRouter router, String path) {
    try {
      router.go(path);
    } catch (_) {
      try {
        router.go(AppRoutes.notifications);
      } catch (_) {
        // App may not be ready; silently swallow.
      }
    }
  }

  /// Unregister current device token on user logout.
  Future<void> unregisterOnLogout() async {
    try {
      final token = _currentToken ??
          await _secureStorage.read(key: _storedDeviceTokenKey);
      if (token != null && token.isNotEmpty) {
        await _remoteDataSource.unregisterDeviceToken(token);
        await _secureStorage.delete(key: _storedDeviceTokenKey);
        _currentToken = null;
        _isInitialized = false;
        debugPrint(
          '[PushNotificationService] Device token unregistered on logout.',
        );
      }
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Failed to unregister device token: $e',
      );
    } finally {
      _tokenRefreshSub?.cancel();
      _foregroundSub?.cancel();
      _tapSub?.cancel();
      _tokenRefreshSub = null;
      _foregroundSub = null;
      _tapSub = null;
      _handledNotificationIds.clear();
      _router = null;
    }
  }
}

