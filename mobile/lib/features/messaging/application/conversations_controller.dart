import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/conversation_entity.dart';
import '../domain/repositories/messaging_repository.dart';
import '../data/datasources/messaging_socket_service.dart';

class ConversationsState {
  const ConversationsState({
    this.isLoading = false,
    this.conversations = const [],
    this.errorMessage,
    this.nextCursor,
    this.hasMore = false,
  });

  final bool isLoading;
  final List<ConversationEntity> conversations;
  final String? errorMessage;
  final String? nextCursor;
  final bool hasMore;

  int get totalUnreadCount =>
      conversations.fold<int>(0, (sum, conv) => sum + conv.unreadCount);

  ConversationsState copyWith({
    bool? isLoading,
    List<ConversationEntity>? conversations,
    String? errorMessage,
    String? nextCursor,
    bool? hasMore,
  }) {
    return ConversationsState(
      isLoading: isLoading ?? this.isLoading,
      conversations: conversations ?? this.conversations,
      errorMessage: errorMessage,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final conversationsControllerProvider =
    StateNotifierProvider<ConversationsController, ConversationsState>((ref) {
  final repository = ref.watch(messagingRepositoryProvider);
  final socketService = ref.watch(messagingSocketServiceProvider);
  return ConversationsController(repository, socketService);
});

final totalUnreadMessagesProvider = Provider<int>((ref) {
  final state = ref.watch(conversationsControllerProvider);
  return state.totalUnreadCount;
});

class ConversationsController extends StateNotifier<ConversationsState> {
  ConversationsController(this._repository, this._socketService)
      : super(const ConversationsState(isLoading: true)) {
    loadConversations();
    _subscribeToSocketEvents();
  }

  final MessagingRepository _repository;
  final MessagingSocketService _socketService;
  StreamSubscription<Map<String, dynamic>>? _newMessageSub;
  StreamSubscription<Map<String, dynamic>>? _convUpdateSub;

  void _subscribeToSocketEvents() {
    _socketService.connect();

    _newMessageSub = _socketService.onNewMessage.listen((data) {
      final conversationId = data['conversationId'] as String?;
      if (conversationId != null) {
        // Refresh conversation list to get latest preview and unread count
        loadConversations(silent: true);
      }
    });

    _convUpdateSub = _socketService.onConversationUpdate.listen((data) {
      loadConversations(silent: true);
    });
  }

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final result = await _repository.getConversations(limit: 20);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        conversations: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
      );
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load conversations. Please try again.',
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.nextCursor == null) return;

    try {
      final result = await _repository.getConversations(
        cursor: state.nextCursor,
        limit: 20,
      );
      if (!mounted) return;
      state = state.copyWith(
        conversations: [...state.conversations, ...result.items],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
      );
    } catch (_) {}
  }

  void markConversationReadLocally(String conversationId) {
    final updated = state.conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();
    state = state.copyWith(conversations: updated);
  }

  @override
  void dispose() {
    _newMessageSub?.cancel();
    _convUpdateSub?.cancel();
    super.dispose();
  }
}
