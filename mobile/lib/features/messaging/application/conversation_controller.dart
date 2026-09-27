import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../domain/entities/conversation_entity.dart';
import '../domain/entities/message_entity.dart';
import '../domain/repositories/messaging_repository.dart';
import '../data/datasources/messaging_socket_service.dart';
import 'conversations_controller.dart';

class ConversationDetailState {
  const ConversationDetailState({
    this.isLoading = false,
    this.conversation,
    this.messages = const [],
    this.isTyping = false,
    this.isOnline = false,
    this.errorMessage,
    this.nextCursor,
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
  });

  final bool isLoading;
  final ConversationEntity? conversation;
  final List<MessageEntity> messages;
  final bool isTyping;
  final bool isOnline;
  final String? errorMessage;
  final String? nextCursor;
  final bool hasMoreOlder;
  final bool isLoadingOlder;

  ConversationDetailState copyWith({
    bool? isLoading,
    ConversationEntity? conversation,
    List<MessageEntity>? messages,
    bool? isTyping,
    bool? isOnline,
    String? errorMessage,
    String? nextCursor,
    bool? hasMoreOlder,
    bool? isLoadingOlder,
  }) {
    return ConversationDetailState(
      isLoading: isLoading ?? this.isLoading,
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      isTyping: isTyping ?? this.isTyping,
      isOnline: isOnline ?? this.isOnline,
      errorMessage: errorMessage,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
    );
  }
}

final conversationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConversationController, ConversationDetailState, String>(
  (ref, conversationId) {
    final repository = ref.watch(messagingRepositoryProvider);
    final socketService = ref.watch(messagingSocketServiceProvider);
    final authState = ref.watch(authControllerProvider);
    String? currentUserId;
    if (authState is AuthAuthenticated) {
      currentUserId = authState.user.id;
    } else if (authState is AuthOnboardingRequired) {
      currentUserId = authState.user.id;
    }

    final controller = ConversationController(
      conversationId: conversationId,
      repository: repository,
      socketService: socketService,
      currentUserId: currentUserId,
      ref: ref,
    );

    return controller;
  },
);

class ConversationController extends StateNotifier<ConversationDetailState> {
  ConversationController({
    required this.conversationId,
    required this.repository,
    required this.socketService,
    required this.currentUserId,
    required this.ref,
  }) : super(const ConversationDetailState(isLoading: true)) {
    loadConversation();
    _setupSocketListeners();
  }

  final String conversationId;
  final MessagingRepository repository;
  final MessagingSocketService socketService;
  final String? currentUserId;
  final Ref ref;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _typingDebounce;

  void _setupSocketListeners() {
    socketService.connect();
    socketService.joinConversation(conversationId);

    // New message event
    _subscriptions.add(
      socketService.onNewMessage.listen((data) {
        final cid = data['conversationId'] as String?;
        if (cid == conversationId) {
          final clientMsgId = data['clientMessageId'] as String? ?? '';
          final senderId = data['senderId'] as String? ?? '';
          final isMe = currentUserId != null && senderId == currentUserId;

          // Deduplicate if already in list
          final exists = state.messages.any(
            (m) =>
                m.clientMessageId == clientMsgId ||
                (data['id'] != null && m.id == data['id']),
          );

          if (!exists) {
            final newMsg = MessageEntity(
              id: data['id'] as String? ?? '',
              conversationId: conversationId,
              senderId: senderId,
              clientMessageId: clientMsgId,
              content: data['content'] as String? ?? '',
              messageType: data['messageType'] as String? ?? 'TEXT',
              status: MessageStatus.sent,
              createdAt: data['createdAt'] != null
                  ? DateTime.tryParse(data['createdAt'] as String) ??
                      DateTime.now()
                  : DateTime.now(),
              readAt: data['readAt'] != null
                  ? DateTime.tryParse(data['readAt'] as String)
                  : null,
              isMe: isMe,
            );

            state = state.copyWith(messages: [...state.messages, newMsg]);

            if (!isMe) {
              markAsRead();
            }
          }
        }
      }),
    );

    // Message ack event
    _subscriptions.add(
      socketService.onMessageAck.listen((data) {
        final clientMsgId = data['clientMessageId'] as String?;
        final serverMsgId = data['messageId'] as String?;
        if (clientMsgId != null) {
          final updated = state.messages.map((m) {
            if (m.clientMessageId == clientMsgId) {
              return m.copyWith(
                id: serverMsgId ?? m.id,
                status: MessageStatus.sent,
              );
            }
            return m;
          }).toList();
          state = state.copyWith(messages: updated);
        }
      }),
    );

    // Message read event
    _subscriptions.add(
      socketService.onMessageRead.listen((data) {
        if (data['conversationId'] == conversationId) {
          final readAtStr = data['readAt'] as String?;
          final readAt =
              readAtStr != null ? DateTime.tryParse(readAtStr) : DateTime.now();
          final updated = state.messages.map((m) {
            if (m.isMe && m.readAt == null) {
              return m.copyWith(readAt: readAt);
            }
            return m;
          }).toList();
          state = state.copyWith(messages: updated);
        }
      }),
    );

    // Typing start
    _subscriptions.add(
      socketService.onTypingStart.listen((data) {
        if (data['conversationId'] == conversationId &&
            data['userId'] != currentUserId) {
          state = state.copyWith(isTyping: true);
          _typingDebounce?.cancel();
          _typingDebounce = Timer(const Duration(seconds: 4), () {
            if (mounted) state = state.copyWith(isTyping: false);
          });
        }
      }),
    );

    // Typing stop
    _subscriptions.add(
      socketService.onTypingStop.listen((data) {
        if (data['conversationId'] == conversationId &&
            data['userId'] != currentUserId) {
          state = state.copyWith(isTyping: false);
        }
      }),
    );

    // Presence update
    _subscriptions.add(
      socketService.onPresenceUpdate.listen((data) {
        if (state.conversation != null &&
            data['userId'] == state.conversation!.participant.id) {
          final isOnline = data['status'] == 'online';
          state = state.copyWith(isOnline: isOnline);
        }
      }),
    );
  }

  Future<void> loadConversation() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final conv = await repository.getConversationById(conversationId);
      final messagesRes =
          await repository.getMessages(conversationId, limit: 30);

      // Backend returns newest first. Reverse for chronological display (oldest to newest)
      final chronological = messagesRes.items.reversed.toList();

      state = state.copyWith(
        isLoading: false,
        conversation: conv,
        messages: chronological,
        isOnline: conv.isOnline,
        nextCursor: messagesRes.nextCursor,
        hasMoreOlder: messagesRes.hasMore,
      );

      // Mark unread messages as read
      markAsRead();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load conversation. Please try again.',
      );
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.isLoadingOlder ||
        !state.hasMoreOlder ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true);

    try {
      final res = await repository.getMessages(
        conversationId,
        cursor: state.nextCursor,
        limit: 30,
      );

      final olderChronological = res.items.reversed.toList();

      state = state.copyWith(
        isLoadingOlder: false,
        messages: [...olderChronological, ...state.messages],
        nextCursor: res.nextCursor,
        hasMoreOlder: res.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  /// Send message with optimistic UI and duplicate protection
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final clientMsgId =
        'cl_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

    final optimistic = MessageEntity(
      id: clientMsgId,
      conversationId: conversationId,
      senderId: currentUserId ?? '',
      clientMessageId: clientMsgId,
      content: trimmed,
      messageType: 'TEXT',
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      isMe: true,
    );

    // 1. Immediately render in UI
    state = state.copyWith(messages: [...state.messages, optimistic]);

    // 2. Transmit via WebSocket if connected, otherwise via REST fallback
    if (socketService.isConnected) {
      socketService.sendMessage(
        conversationId: conversationId,
        clientMessageId: clientMsgId,
        content: trimmed,
      );

      // Safety timeout: if server ack not received in 8s, mark failed
      Future.delayed(const Duration(seconds: 8), () {
        if (!mounted) return;
        final current = state.messages.firstWhere(
          (m) => m.clientMessageId == clientMsgId,
          orElse: () => optimistic,
        );
        if (current.status == MessageStatus.sending) {
          final updated = state.messages.map((m) {
            if (m.clientMessageId == clientMsgId) {
              return m.copyWith(status: MessageStatus.failed);
            }
            return m;
          }).toList();
          state = state.copyWith(messages: updated);
        }
      });
    } else {
      // REST fallback
      try {
        final serverMsg = await repository.sendMessage(
          conversationId,
          clientMessageId: clientMsgId,
          content: trimmed,
        );
        final updated = state.messages.map((m) {
          if (m.clientMessageId == clientMsgId) {
            return m.copyWith(
              id: serverMsg.id,
              status: MessageStatus.sent,
              createdAt: serverMsg.createdAt,
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      } catch (e) {
        final updated = state.messages.map((m) {
          if (m.clientMessageId == clientMsgId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    }
  }

  /// Retry sending a failed message
  Future<void> retryMessage(String clientMessageId) async {
    final message = state.messages.firstWhere(
      (m) => m.clientMessageId == clientMessageId,
      orElse: () => throw Exception('Message not found'),
    );

    // Mark as sending
    final updated = state.messages.map((m) {
      if (m.clientMessageId == clientMessageId) {
        return m.copyWith(status: MessageStatus.sending);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);

    if (socketService.isConnected) {
      socketService.sendMessage(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        content: message.content,
      );
    } else {
      try {
        final serverMsg = await repository.sendMessage(
          conversationId,
          clientMessageId: clientMessageId,
          content: message.content,
        );
        final afterRetry = state.messages.map((m) {
          if (m.clientMessageId == clientMessageId) {
            return m.copyWith(
              id: serverMsg.id,
              status: MessageStatus.sent,
              createdAt: serverMsg.createdAt,
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: afterRetry);
      } catch (_) {
        final afterRetry = state.messages.map((m) {
          if (m.clientMessageId == clientMessageId) {
            return m.copyWith(status: MessageStatus.failed);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: afterRetry);
      }
    }
  }

  void onTypingInput(String text) {
    if (text.isNotEmpty) {
      socketService.startTyping(conversationId);
    } else {
      socketService.stopTyping(conversationId);
    }
  }

  Future<void> markAsRead() async {
    try {
      socketService.markAsRead(conversationId);
      await repository.markAsRead(conversationId);
      ref
          .read(conversationsControllerProvider.notifier)
          .markConversationReadLocally(conversationId);
    } catch (_) {}
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await repository.deleteMessage(messageId);
      final updated = state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(content: 'This message was deleted');
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    } catch (_) {}
  }

  Future<bool> reportConversation({
    required String reason,
    String? description,
    String? messageId,
  }) async {
    try {
      await repository.reportConversation(
        conversationId,
        reason: reason,
        description: description,
        messageId: messageId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> blockParticipant() async {
    if (state.conversation == null) return false;
    try {
      await repository.blockUser(state.conversation!.participant.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    socketService.stopTyping(conversationId);
    socketService.leaveConversation(conversationId);
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}
