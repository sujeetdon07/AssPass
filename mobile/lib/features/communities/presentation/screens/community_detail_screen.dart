import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../application/community_detail_controller.dart';
import '../widgets/community_header.dart';
import '../widgets/join_leave_dialogs.dart';
import '../widgets/report_community_dialog.dart';

/// Screen displaying a single community's header, membership actions, and community-scoped post feed.
class CommunityDetailScreen extends ConsumerStatefulWidget {
  const CommunityDetailScreen({
    required this.communityId,
    super.key,
  });

  final String communityId;

  @override
  ConsumerState<CommunityDetailScreen> createState() =>
      _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> {
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
      ref
          .read(communityDetailControllerProvider(widget.communityId).notifier)
          .loadMorePosts();
    }
  }

  Future<void> _handleJoinToggle() async {
    final controller = ref
        .read(communityDetailControllerProvider(widget.communityId).notifier);
    final state =
        ref.read(communityDetailControllerProvider(widget.communityId));
    final community = state.community;
    if (community == null) return;

    if (community.currentUserMember) {
      if (community.isOwner) {
        // Owner cannot leave
        await showOwnerCannotLeaveDialog(context);
        return;
      }

      final confirmed = await showLeaveCommunityDialog(
        context,
        communityName: community.name,
        isPrivate: community.isPrivate,
      );
      if (confirmed == true && mounted) {
        final success = await controller.leave();
        if (mounted && success) {
          AppSnackbar.showInfo(
            context,
            message: 'You have left ${community.name}',
          );
        }
      }
    } else {
      final success = await controller.join();
      if (mounted && success) {
        AppSnackbar.showSuccess(
          context,
          message: 'Welcome to ${community.name}!',
        );
      }
    }
  }

  Future<void> _handleReport() async {
    final state =
        ref.read(communityDetailControllerProvider(widget.communityId));
    final community = state.community;
    if (community == null) return;

    final controller = ref
        .read(communityDetailControllerProvider(widget.communityId).notifier);

    final success = await showReportCommunityDialog(
      context,
      communityName: community.name,
      onSubmit: (reason, details) =>
          controller.report(reason: reason, details: details),
    );

    if (success == true && mounted) {
      AppSnackbar.showSuccess(
        context,
        message:
            'Report submitted. Our moderation team will review this community.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state =
        ref.watch(communityDetailControllerProvider(widget.communityId));
    final authState = ref.watch(authControllerProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && state.community == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage!,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVMd,
              FilledButton(
                onPressed: () => ref
                    .read(
                      communityDetailControllerProvider(widget.communityId)
                          .notifier,
                    )
                    .loadDetails(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final community = state.community!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          community.name,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            onSelected: (val) {
              if (val == 'report') {
                _handleReport();
              } else if (val == 'edit') {
                context.push(
                  '/communities/${community.id}/edit',
                  extra: community,
                );
              } else if (val == 'share') {
                AppSnackbar.showInfo(
                  context,
                  message: 'Community link copied to clipboard.',
                );
              }
            },
            itemBuilder: (context) => [
              if (community.isModerator)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Community'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(AppIcons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Share Community'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(AppIcons.report, size: 18),
                    SizedBox(width: 8),
                    Text('Report Community'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: state.canViewPosts && community.currentUserMember
          ? FloatingActionButton.extended(
              onPressed: () {
                context.push(
                  '/feed/create',
                  extra: {
                    'communityId': community.id,
                    'communityName': community.name,
                  },
                );
              },
              icon: const Icon(AppIcons.add),
              label: const Text('New Post'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(
              communityDetailControllerProvider(widget.communityId).notifier,
            )
            .loadDetails(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Community Header Card
            SliverToBoxAdapter(
              child: CommunityHeader(
                community: community,
                isLoadingJoin: state.isActionLoading,
                onJoinToggle: _handleJoinToggle,
                onViewMembers: () {
                  context.push('/communities/${community.id}/members');
                },
              ),
            ),

            // Feed Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Community Discussions',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ),

            // Content: Private Gate OR Posts Feed
            if (!state.canViewPosts)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: AppEmptyState(
                      icon: AppIcons.lock,
                      title: 'Private Community',
                      description:
                          'This community is private to members only. Join to see posts, participate in discussions, and connect with neighbors.',
                      actionText: 'Join Community',
                      onAction: _handleJoinToggle,
                    ),
                  ),
                ),
              )
            else if (state.isLoadingPosts && state.posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: AppEmptyState(
                      icon: AppIcons.comment,
                      title: 'No posts yet',
                      description: community.currentUserMember
                          ? 'Be the first neighbor to post or start a discussion in this community!'
                          : 'No posts have been made here yet.',
                      actionText:
                          community.currentUserMember ? 'Create Post' : null,
                      onAction: community.currentUserMember
                          ? () {
                              context.push(
                                '/feed/create',
                                extra: {
                                  'communityId': community.id,
                                  'communityName': community.name,
                                },
                              );
                            }
                          : null,
                    ),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = state.posts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: PostCard(
                          post: post,
                          currentUserId: currentUserId,
                          onTap: () => context.push('/feed/posts/${post.id}'),
                          onLikePressed: () {
                            ref
                                .read(
                                  communityDetailControllerProvider(
                                    widget.communityId,
                                  ).notifier,
                                )
                                .togglePostLike(post.id);
                          },
                          onCommentPressed: () =>
                              context.push('/feed/posts/${post.id}'),
                        ),
                      );
                    },
                    childCount: state.posts.length,
                  ),
                ),
              ),

              // Bottom Loader for Infinite Scroll
              if (state.isLoadingMorePosts)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
