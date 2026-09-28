import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../feed/application/feed_controller.dart';
import '../../../feed/data/repositories/feed_repository.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../feed/presentation/widgets/report_content_dialog.dart';

/// The Community Feed Home Screen for Aaspaas.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final feedState = ref.watch(feedControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;
    final localityDisplay = authState is AuthAuthenticated
        ? authState.user.localitySummary
        : 'Your Neighborhood';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(feedControllerProvider.notifier).loadFeed(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Top Bar: Locality Scope & Create Post Prompt ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Column(
                  children: [
                    // Quick Composer Card (Soft clay dimensional container)
                    InkWell(
                      onTap: () => context.push('/feed/create'),
                      borderRadius: BorderRadius.circular(24.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkOutlineVariant
                                : const Color(0xFFECEEF5),
                            width: 0.8,
                          ),
                          boxShadow: isDark
                              ? AppElevation.shadowDarkCard
                              : AppElevation.shadowCard,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AppAvatar(
                              name: authState is AuthAuthenticated
                                  ? authState.user.displayName
                                  : 'You',
                              size: AppAvatarSize.s32,
                            ),
                            AppSpacing.gapHSm,
                            Expanded(
                              child: Text(
                                "What's happening in $localityDisplay?",
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            AppSpacing.gapHSm,
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E284A)
                                    : const Color(0xFFEEF0FF),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Hyperlocal Discovery Shortcuts (3 Side-by-Side Cards) ──
                    Row(
                      children: [
                        // Businesses
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/businesses'),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.quickActionBusinessBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkOutlineVariant
                                      : const Color(0xFFECEFFE),
                                  width: 0.8,
                                ),
                                boxShadow: isDark
                                    ? null
                                    : AppElevation.shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E284A)
                                          : AppColors.quickActionBusinessIconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      AppIcons.business,
                                      size: 16,
                                      color: isDark
                                          ? AppColors.darkPrimary
                                          : AppColors.quickActionBusinessIcon,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Businesses',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.slate400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Local shops & dining',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 9.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Services
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/services'),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.quickActionServicesBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkOutlineVariant
                                      : const Color(0xFFE5F7F0),
                                  width: 0.8,
                                ),
                                boxShadow: isDark
                                    ? null
                                    : AppElevation.shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF064E3B)
                                          : AppColors.quickActionServicesIconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      AppIcons.service,
                                      size: 16,
                                      color: isDark
                                          ? AppColors.emerald500
                                          : AppColors.quickActionServicesIcon,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Services',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.slate400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Electricians, tutors...',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 9.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Local Events
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/events'),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.quickActionEventsBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkOutlineVariant
                                      : const Color(0xFFFCECF6),
                                  width: 0.8,
                                ),
                                boxShadow: isDark
                                    ? null
                                    : AppElevation.shadowSm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF4C0519)
                                          : AppColors.quickActionEventsIconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.calendar_month_outlined,
                                      size: 16,
                                      color: isDark
                                          ? AppColors.rose500
                                          : AppColors.quickActionEventsIcon,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Local Events',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 14,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.slate400,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Meetups, workshops...',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 9.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          AppChip(
                            label: 'All Updates',
                            icon: feedState.selectedCategory == null
                                ? Icons.check_rounded
                                : null,
                            isSelected: feedState.selectedCategory == null,
                            onSelected: (_) {
                              ref
                                  .read(feedControllerProvider.notifier)
                                  .setCategory(null);
                            },
                          ),
                          AppSpacing.gapHSm,
                          ...PostCategory.values.map((cat) {
                            final isSelected =
                                feedState.selectedCategory == cat;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: AppChip(
                                label: cat.label,
                                icon: cat.icon,
                                isSelected: isSelected,
                                onSelected: (_) {
                                  ref
                                      .read(feedControllerProvider.notifier)
                                      .setCategory(cat);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Feed Content / Empty / Error / Loading States ────────────────
            if (feedState.isLoading && feedState.posts.isEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppSkeleton(
                        width: double.infinity,
                        height: 140,
                      ),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
            ] else if (feedState.hasError && feedState.posts.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: AppErrorState(
                      title: 'Feed unavailable',
                      message: feedState.errorMessage ??
                          'Unable to load community posts.',
                      onRetry: () =>
                          ref.read(feedControllerProvider.notifier).loadFeed(),
                    ),
                  ),
                ),
              ),
            ] else if (feedState.isEmpty ||
                (feedState.isRefreshing && feedState.posts.isEmpty)) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: AppEmptyState(
                        icon: AppIcons.communities,
                        title: 'No posts in $localityDisplay yet',
                        description:
                            'Be the first neighbor to post an update, alert, or question in your area!',
                        actionText: 'Create First Post',
                        onAction: () => context.push('/feed/create'),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = feedState.posts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PostCard(
                          post: post,
                          currentUserId: currentUserId,
                          onTap: () => context.push('/feed/posts/${post.id}'),
                          onLikePressed: () {
                            ref
                                .read(feedControllerProvider.notifier)
                                .toggleLike(post.id);
                          },
                          onCommentPressed: () =>
                              context.push('/feed/posts/${post.id}'),
                          onEditPressed: () => context.push(
                            '/feed/posts/${post.id}/edit',
                            extra: post,
                          ),
                          onDeletePressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Post?'),
                                content: const Text(
                                  'Are you sure you want to delete this post? This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: AppColors.rose600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && mounted) {
                              try {
                                await ref
                                    .read(feedRepositoryProvider)
                                    .deletePost(post.id);
                                ref
                                    .read(feedControllerProvider.notifier)
                                    .removePost(post.id);
                                if (!context.mounted) return;
                                AppSnackbar.showSuccess(
                                  context,
                                  message: 'Post deleted successfully.',
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                AppSnackbar.showError(
                                  context,
                                  message: 'Failed to delete post.',
                                );
                              }
                            }
                          },
                          onReportPressed: () {
                            ReportContentDialog.show(
                              context,
                              targetId: post.id,
                              targetType: ReportType.post,
                            );
                          },
                        ),
                      );
                    },
                    childCount: feedState.posts.length,
                  ),
                ),
              ),
              if (feedState.isLoadingMore) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppElevation.shadowFab,
        ),
        child: FloatingActionButton(
          onPressed: () => context.push('/feed/create'),
          backgroundColor:
              isDark ? AppColors.darkPrimary : const Color(0xFF4F46E5),
          foregroundColor: AppColors.pureWhite,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          tooltip: 'Create Post',
          child: const Icon(AppIcons.add, size: 28, color: AppColors.pureWhite),
        ),
      ),
    );
  }
}
