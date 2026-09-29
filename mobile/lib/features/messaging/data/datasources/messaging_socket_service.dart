import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage_service.dart';

enum SocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

final messagingSocketServiceProvider = Provider<MessagingSocketService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final service = MessagingSocketService(secureStorage);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class MessagingSocketService {
  MessagingSocketService(this._secureStorage);

  final SecureStorageService _secureStorage;
  io.Socket? _socket;

  final _connectionStatusController =
      StreamController<SocketConnectionStatus>.broadcast();
  Stream<SocketConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  SocketConnectionStatus _currentStatus = SocketConnectionStatus.disconnected;
  SocketConnectionStatus get currentStatus => _currentStatus;

  // Event streams
  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewMessage => _newMessageController.stream;

  final _messageAckController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageAck => _messageAckController.stream;

  final _messageReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onMessageRead =>
      _messageReadController.stream;

  final _typingStartController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTypingStart =>
      _typingStartController.stream;

  final _typingStopController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTypingStop => _typingStopController.stream;

  final _presenceUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPresenceUpdate =>
      _presenceUpdateController.stream;

  final _conversationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onConversationUpdate =>
      _conversationUpdateController.stream;

  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onError => _errorController.stream;

  // Notification event streams
  final _newNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewNotification =>
      _newNotificationController.stream;

  final _notificationReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationRead =>
      _notificationReadController.stream;

  final _notificationUnreadCountController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationUnreadCount =>
      _notificationUnreadCountController.stream;

  bool get isConnected =>
      _socket != null &&
      _socket!.connected &&
      _currentStatus == SocketConnectionStatus.connected;

  Future<void> connect() async {
    if (isConnected || _currentStatus == SocketConnectionStatus.connecting) {
      return;
    }

    _setStatus(SocketConnectionStatus.connecting);

    final token = await _secureStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      _setStatus(SocketConnectionStatus.disconnected);
      return;
    }

    try {
      // Derive baseUrl without /api/v1 (e.g. http://10.0.2.2:3000)
      final apiBase = AppConfig.apiBaseUrl;
      final uri = Uri.parse(apiBase);
      final socketBaseUrl = '${uri.scheme}://${uri.host}:${uri.port}/messaging';

      _socket = io.io(
        socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(10)
            .build(),
      );

      _socket!.onConnect((_) {
        debugPrint('[MessagingSocket] Connected to $socketBaseUrl');
        _setStatus(SocketConnectionStatus.connected);
      });

      _socket!.onDisconnect((_) {
        debugPrint('[MessagingSocket] Disconnected');
        _setStatus(SocketConnectionStatus.disconnected);
      });

      _socket!.onConnectError((err) {
        debugPrint('[MessagingSocket] Connect error: $err');
        _setStatus(SocketConnectionStatus.error);
      });

      _socket!.onError((err) {
        debugPrint('[MessagingSocket] Socket error: $err');
        if (err is Map<String, dynamic>) {
          _errorController.add(err);
        }
      });

      // Register server events
      _socket!.on('message:new', (data) {
        if (data is Map<String, dynamic>) {
          _newMessageController.add(data);
        } else if (data is Map) {
          _newMessageController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('message:ack', (data) {
        if (data is Map<String, dynamic>) {
          _messageAckController.add(data);
        } else if (data is Map) {
          _messageAckController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('message:read', (data) {
        if (data is Map<String, dynamic>) {
          _messageReadController.add(data);
        } else if (data is Map) {
          _messageReadController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('typing:start', (data) {
        if (data is Map<String, dynamic>) {
          _typingStartController.add(data);
        } else if (data is Map) {
          _typingStartController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('typing:stop', (data) {
        if (data is Map<String, dynamic>) {
          _typingStopController.add(data);
        } else if (data is Map) {
          _typingStopController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('presence:update', (data) {
        if (data is Map<String, dynamic>) {
          _presenceUpdateController.add(data);
        } else if (data is Map) {
          _presenceUpdateController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('conversation:update', (data) {
        if (data is Map<String, dynamic>) {
          _conversationUpdateController.add(data);
        } else if (data is Map) {
          _conversationUpdateController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('notification:new', (data) {
        if (data is Map<String, dynamic>) {
          _newNotificationController.add(data);
        } else if (data is Map) {
          _newNotificationController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('notification:read', (data) {
        if (data is Map<String, dynamic>) {
          _notificationReadController.add(data);
        } else if (data is Map) {
          _notificationReadController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('notification:unread-count', (data) {
        if (data is Map<String, dynamic>) {
          _notificationUnreadCountController.add(data);
        } else if (data is Map) {
          _notificationUnreadCountController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('error', (data) {
        if (data is Map<String, dynamic>) {
          _errorController.add(data);
        } else if (data is Map) {
          _errorController.add(Map<String, dynamic>.from(data));
        }
      });
    } catch (e) {
      debugPrint('[MessagingSocket] Failed to initialize socket: $e');
      _setStatus(SocketConnectionStatus.error);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _setStatus(SocketConnectionStatus.disconnected);
  }

  void joinConversation(String conversationId) {
    if (isConnected) {
      _socket?.emit('conversation:join', {'conversationId': conversationId});
    }
  }

  void leaveConversation(String conversationId) {
    if (isConnected) {
      _socket?.emit('conversation:leave', {'conversationId': conversationId});
    }
  }

  void sendMessage({
    required String conversationId,
    required String clientMessageId,
    required String content,
    String messageType = 'TEXT',
    String? mediaUrl,
    String? mediaThumbnailUrl,
    int? mediaWidth,
    int? mediaHeight,
    int? mediaSize,
    String? mediaMimeType,
  }) {
    if (isConnected) {
      _socket?.emit('message:send', {
        'conversationId': conversationId,
        'clientMessageId': clientMessageId,
        'content': content,
        'messageType': messageType,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaThumbnailUrl != null) 'mediaThumbnailUrl': mediaThumbnailUrl,
        if (mediaWidth != null) 'mediaWidth': mediaWidth,
        if (mediaHeight != null) 'mediaHeight': mediaHeight,
        if (mediaSize != null) 'mediaSize': mediaSize,
        if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
      });
    }
  }

  void markAsRead(String conversationId) {
    if (isConnected) {
      _socket?.emit('message:read', {'conversationId': conversationId});
    }
  }

  void startTyping(String conversationId) {
    if (isConnected) {
      _socket?.emit('typing:start', {'conversationId': conversationId});
    }
  }

  void stopTyping(String conversationId) {
    if (isConnected) {
      _socket?.emit('typing:stop', {'conversationId': conversationId});
    }
  }

  void subscribePresence(String userId) {
    if (isConnected) {
      _socket?.emit('presence:subscribe', {'userId': userId});
    }
  }

  void _setStatus(SocketConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _newMessageController.close();
    _messageAckController.close();
    _messageReadController.close();
    _typingStartController.close();
    _typingStopController.close();
    _presenceUpdateController.close();
    _conversationUpdateController.close();
    _errorController.close();
    _newNotificationController.close();
    _notificationReadController.close();
    _notificationUnreadCountController.close();
  }
}
