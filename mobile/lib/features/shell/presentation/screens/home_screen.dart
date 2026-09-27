import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/cards/app_card.dart';
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
                    // Quick Composer Card
                    AppCard(
                      onTap: () => context.push('/feed/create'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
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
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "What's happening in $localityDisplay?",
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.lightTextTertiary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          AppSpacing.gapHSm,
                          Container(
                            width: 28,
                            height: 28,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkPrimary
                                      .withValues(alpha: 0.15)
                                  : AppColors.lightPrimary
                                      .withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderSm,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              AppIcons.edit,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AppSpacing.gapVSm,

                    // ── Hyperlocal Discovery Shortcuts ──────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/businesses'),
                            borderRadius: AppRadius.card,
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceContainer
                                    : AppColors.lightSurfaceContainer,
                                borderRadius: AppRadius.card,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.slate800
                                      : AppColors.slate200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.indigo600
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      AppIcons.business,
                                      size: 16,
                                      color: AppColors.indigo600,
                                    ),
                                  ),
                                  AppSpacing.gapHSm,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Businesses',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Local shops & dining',
                                          style:
                                              AppTypography.labelSmall.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapHSm,
                        Expanded(
                          child: InkWell(
                            onTap: () => context.push('/services'),
                            borderRadius: AppRadius.card,
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceContainer
                                    : AppColors.lightSurfaceContainer,
                                borderRadius: AppRadius.card,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.slate800
                                      : AppColors.slate200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald500
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      AppIcons.service,
                                      size: 16,
                                      color: AppColors.emerald500,
                                    ),
                                  ),
                                  AppSpacing.gapHSm,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Services',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Electricians, tutors...',
                                          style:
                                              AppTypography.labelSmall.copyWith(
                                            color: isDark
                                                ? AppColors.darkTextSecondary
                                                : AppColors.lightTextSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapVSm,

                    // ── Events Discovery Shortcut ─────────────────────────
                    InkWell(
                      onTap: () => context.push('/events'),
                      borderRadius: AppRadius.card,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.lightSurfaceContainer,
                          borderRadius: AppRadius.card,
                          border: Border.all(
                            color: isDark
                                ? AppColors.slate800
                                : AppColors.slate200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.violet600
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.event_outlined,
                                size: 16,
                                color: AppColors.violet600,
                              ),
                            ),
                            AppSpacing.gapHSm,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Local Events',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Meetups, workshops & sports gatherings',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.slate400,
                            ),
                          ],
                        ),
                      ),
                    ),

                    AppSpacing.gapVSm,

                    // Category Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          AppChip(
                            label: 'All Updates',
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
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
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
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = feedState.posts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/feed/create'),
        backgroundColor:
            isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
        foregroundColor: AppColors.pureWhite,
        tooltip: 'Create Post',
        child: const Icon(AppIcons.add),
      ),
    );
  }
}
