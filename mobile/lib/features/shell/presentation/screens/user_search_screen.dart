import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../messaging/domain/repositories/messaging_repository.dart';

/// Screen allowing neighbors to search other users by @username or display name.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<UserSearchResult> _results = [];
  bool _isLoading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();

    if (clean.isEmpty) {
      setState(() {
        _lastQuery = '';
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _lastQuery = clean;
      _isLoading = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results =
            await ref.read(authRepositoryProvider).searchUsers(clean);
        if (!mounted) return;
        if (_searchController.text.trim() != clean) return;

        setState(() {
          _results = results;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _startConversation(String userId) async {
    try {
      final conv = await ref
          .read(messagingRepositoryProvider)
          .createOrGetConversation(userId);
      if (mounted) {
        context.push('/messages/${conv.id}');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Find Neighbors',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppSearchBar(
                controller: _searchController,
                hint: 'Search by @username or name...',
                onChanged: _onQueryChanged,
                onClear: () {
                  _searchController.clear();
                  _onQueryChanged('');
                },
              ),
            ),
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _buildResults(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, bool isDark) {
    if (_lastQuery.isEmpty) {
      return const AppEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Search for Neighbors',
        description:
            'Type a username like @sujeet or full name to discover neighbors.',
      );
    }

    if (!_isLoading && _results.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No Neighbors Found',
        description: 'No one matched "$_lastQuery". Try a different search term.',
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 72,
        color: isDark
            ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
            : AppColors.lightOutlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final user = _results[index];
        final handle = user.handle;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: AppAvatar(
            imageUrl: user.avatarUrl,
            name: user.displayName,
            size: AppAvatarSize.s48,
          ),
          title: Text(
            user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (handle != null)
                Text(
                  handle,
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkPrimary
                        : AppColors.lightPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              Text(
                user.localitySummary,
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            tooltip: 'Message',
            onPressed: () => _startConversation(user.id),
          ),
          onTap: () {
            if (user.username != null && user.username!.isNotEmpty) {
              context.push('/@${user.username}');
            }
          },
        );
      },
    );
  }
}
