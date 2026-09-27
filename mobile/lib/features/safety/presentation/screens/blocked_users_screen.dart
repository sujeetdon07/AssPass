import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/feedback/app_dialog.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/blocked_users_controller.dart';
import '../../domain/models/blocked_user_record.dart';

/// Screen displaying the list of users blocked by the current user.
///
/// Accessible from Profile → Privacy & Safety → Blocked Users.
/// Each row shows a safe public profile (display name + locality badge)
/// and an Unblock action that removes the block optimistically.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(blockedUsersControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _unblock(BlockedUserRecord record) async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Unblock ${record.displayName}?',
      message:
          '${record.displayName} will be able to see your posts and send you messages.',
      confirmText: 'Unblock',
      cancelText: 'Cancel',
      isDestructive: false,
      icon: Icons.block_rounded,
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(blockedUsersControllerProvider.notifier)
        .unblock(record.blockedUserId);

    if (mounted) {
      if (success) {
        AppSnackbar.showSuccess(
          context,
          message: '${record.displayName} has been unblocked.',
        );
      } else {
        AppSnackbar.showError(
          context,
          message: 'Unable to unblock user. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final safetyState = ref.watch(blockedUsersControllerProvider);
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go(AppRoutes.profile);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: Text(
            'Blocked Users',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () => canPop
                ? Navigator.of(context).pop()
                : context.go(AppRoutes.profile),
          ),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Builder(
        builder: (context) {
          // Loading state
          if (safetyState.isLoading) {
            return ListView.separated(
              padding: AppSpacing.screenPadding,
              itemCount: 5,
              separatorBuilder: (_, __) => AppSpacing.gapVSm,
              itemBuilder: (_, __) => const AppSkeleton(
                width: double.infinity,
                height: 72,
                borderRadius: AppRadius.borderMd,
              ),
            );
          }

          // Error state
          if (safetyState.hasError) {
            return AppErrorState(
              message: safetyState.error ?? 'Something went wrong.',
              onRetry: () =>
                  ref.read(blockedUsersControllerProvider.notifier).load(),
            );
          }

          // Empty state
          if (safetyState.items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.block_outlined,
              title: 'No Blocked Users',
              description:
                  'Users you block won\'t be able to see your posts or contact you. '
                  'Your blocked list is only visible to you.',
            );
          }

          // Populated list
          return Column(
            children: [
              // Count header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      '${safetyState.items.length}${safetyState.hasMore ? '+' : ''} blocked',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  itemCount: safetyState.items.length +
                      (safetyState.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    if (index == safetyState.items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      );
                    }

                    final record = safetyState.items[index];
                    return _BlockedUserTile(
                      record: record,
                      isDark: isDark,
                      onUnblock: () => _unblock(record),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
  }
}

// ── Private tile widget ───────────────────────────────────────────────────────

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.record,
    required this.isDark,
    required this.onUnblock,
  });

  final BlockedUserRecord record;
  final bool isDark;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        isDark ? AppColors.darkSurfaceContainer : AppColors.lightSurface;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.lightOutlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Avatar
            AppAvatar(
              size: AppAvatarSize.s48,
              imageUrl: record.avatarUrl,
              name: record.displayName,
              semanticLabel: '${record.displayName} avatar',
            ),
            AppSpacing.gapHSm,

            // Name + locality
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.displayName,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (record.locality != null || record.city != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            [record.locality, record.city]
                                .where((s) => s != null)
                                .join(', '),
                            style: AppTypography.bodySmall.copyWith(
                              color: textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            AppSpacing.gapHSm,

            // Unblock button
            OutlinedButton(
              onPressed: onUnblock,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkOutline
                      : AppColors.lightOutline,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderSm,
                ),
                minimumSize: const Size(0, 34),
              ),
              child: Text(
                'Unblock',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
