import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/conversation_controller.dart';
import '../../domain/entities/message_entity.dart';
import '../../l10n/messaging_localizations.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/typing_indicator_widget.dart';
import '../../../safety/domain/models/safety_enums.dart';
import '../../../safety/presentation/widgets/report_content_sheet.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.conversationId,
    super.key,
  });

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _onBlock() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(MessagingStrings.of(context, 'blockUser')),
          content: const Text(
            'Blocking this user will prevent them from messaging you or seeing your contact status. This action can be undone later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.rose600),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final success = await ref
                    .read(
                      conversationControllerProvider(widget.conversationId)
                          .notifier,
                    )
                    .blockParticipant();
                if (mounted) {
                  if (success) {
                    AppSnackbar.showSuccess(context, message: 'User blocked.');
                    context.pop();
                  } else {
                    AppSnackbar.showError(
                      context,
                      message: 'Failed to block user.',
                    );
                  }
                }
              },
              child: const Text('Block User'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state =
        ref.watch(conversationControllerProvider(widget.conversationId));
    final participant = state.conversation?.participant;

    // Auto-scroll on new message
    ref.listen(
      conversationControllerProvider(widget.conversationId)
          .select((s) => s.messages.length),
      (prev, next) {
        if (next > (prev ?? 0)) {
          _scrollToBottom();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: participant != null
            ? Row(
                children: [
                  AppAvatar(
                    name: participant.displayName,
                    imageUrl: participant.avatarUrl,
                    size: AppAvatarSize.s32,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                participant.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (participant.handle != null) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  participant.handle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.lightTextTertiary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          state.isTyping
                              ? MessagingStrings.of(context, 'typing')
                              : (state.isOnline
                                  ? MessagingStrings.of(context, 'online')
                                  : participant.localitySummary),
                          style: AppTypography.labelSmall.copyWith(
                            color: state.isTyping
                                ? (isDark
                                    ? AppColors.indigo300
                                    : AppColors.indigo600)
                                : (state.isOnline
                                    ? AppColors.emerald500
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary)),
                            fontWeight: state.isTyping || state.isOnline
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Text(MessagingStrings.of(context, 'messages')),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'report_user' && participant != null) {
                ReportContentSheet.show(
                  context,
                  targetId: participant.id,
                  targetType: ReportTargetType.user,
                );
              }
              if (val == 'report') {
                ReportContentSheet.show(
                  context,
                  targetId: widget.conversationId,
                  targetType: ReportTargetType.conversation,
                );
              }
              if (val == 'block') _onBlock();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report_user',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20),
                    SizedBox(width: AppSpacing.sm),
                    Text('Report User'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(MessagingStrings.of(context, 'reportConversation')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      size: 20,
                      color: AppColors.rose500,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      MessagingStrings.of(context, 'blockUser'),
                      style: const TextStyle(color: AppColors.rose500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(context, ref, state, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ConversationDetailState state,
    bool isDark,
  ) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.messages.isEmpty) {
      return Center(
        child: AppErrorState(
          message: state.errorMessage!,
          onRetry: () => ref
              .read(
                conversationControllerProvider(widget.conversationId).notifier,
              )
              .loadConversation(),
        ),
      );
    }

    return Column(
      children: [
        // Message list
        Expanded(
          child: state.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          MessagingStrings.of(context, 'noMessagesYet'),
                          style: AppTypography.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          MessagingStrings.of(
                            context,
                            'startConversationPrompt',
                          ),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: state.messages.length + (state.isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length && state.isTyping) {
                      return const TypingIndicatorWidget();
                    }

                    final message = state.messages[index];
                    final showDateDivider =
                        _shouldShowDateDivider(index, state.messages);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDateDivider)
                          _buildDateDivider(message.createdAt, isDark),
                        MessageBubble(
                          message: message,
                          onRetry: message.isFailed
                              ? () {
                                  ref
                                      .read(
                                        conversationControllerProvider(
                                          widget.conversationId,
                                        ).notifier,
                                      )
                                      .retryMessage(message.clientMessageId);
                                }
                              : null,
                          onLongPress: message.isMe
                              ? () {
                                  _showMessageOptions(message.id);
                                }
                              : null,
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Composer
        MessageComposer(
          onSend: (text) {
            ref
                .read(
                  conversationControllerProvider(widget.conversationId)
                      .notifier,
                )
                .sendMessage(text);
            _scrollToBottom();
          },
          onTyping: (text) {
            ref
                .read(
                  conversationControllerProvider(widget.conversationId)
                      .notifier,
                )
                .onTypingInput(text);
          },
        ),
      ],
    );
  }

  bool _shouldShowDateDivider(int index, List<MessageEntity> messages) {
    if (index == 0) return true;
    final curr = messages[index].createdAt;
    final prev = messages[index - 1].createdAt;
    return curr.year != prev.year ||
        curr.month != prev.month ||
        curr.day != prev.day;
  }

  Widget _buildDateDivider(DateTime dt, bool isDark) {
    final now = DateTime.now();
    final local = dt.toLocal();
    String label;
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      label = 'Today';
    } else if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${local.day}/${local.month}/${local.year}';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainer,
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontSize: 10,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(String messageId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.rose500,
                ),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: AppColors.rose500),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref
                      .read(
                        conversationControllerProvider(widget.conversationId)
                            .notifier,
                      )
                      .deleteMessage(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
