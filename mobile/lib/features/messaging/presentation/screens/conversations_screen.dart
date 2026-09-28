import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../application/conversations_controller.dart';
import '../../l10n/messaging_localizations.dart';
import '../widgets/conversation_list_tile.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(conversationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          MessagingStrings.of(context, 'messages'),
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded),
            tooltip: 'Find Neighbors',
            onPressed: () {
              context.push('/users/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref
                  .read(conversationsControllerProvider.notifier)
                  .loadConversations();
            },
          ),
        ],
      ),
      body: _buildBody(context, ref, state, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ConversationsState state,
    bool isDark,
  ) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.conversations.isEmpty) {
      return Center(
        child: AppErrorState(
          message: state.errorMessage!,
          onRetry: () => ref
              .read(conversationsControllerProvider.notifier)
              .loadConversations(),
        ),
      );
    }

    if (state.conversations.isEmpty) {
      return AppEmptyState(
        icon: Icons.forum_outlined,
        title: MessagingStrings.of(context, 'noConversationsYet'),
        description: MessagingStrings.of(context, 'startConversationPrompt'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(conversationsControllerProvider.notifier)
          .loadConversations(),
      child: ListView.separated(
        itemCount: state.conversations.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.5,
          indent: 76,
          color: isDark
              ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
              : AppColors.lightOutlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, index) {
          final conv = state.conversations[index];
          return ConversationListTile(
            conversation: conv,
            onTap: () {
              context.push('/messages/${conv.id}');
            },
          );
        },
      ),
    );
  }
}
