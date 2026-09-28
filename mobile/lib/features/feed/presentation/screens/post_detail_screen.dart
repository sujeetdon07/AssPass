import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../core/services/app_share_service.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/post_detail_controller.dart';
import '../../domain/entities/comment_entity.dart';
import '../widgets/post_card.dart';
import '../widgets/report_content_dialog.dart';

/// Screen displaying full details of a post, including interactive comments thread and comment composer.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    required this.postId,
    super.key,
  });

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(postDetailControllerProvider(widget.postId).notifier)
          .loadMoreComments();
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final controller =
        ref.read(postDetailControllerProvider(widget.postId).notifier);
    final success = await controller.submitComment(text);

    if (success) {
      _commentController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else if (mounted) {
      AppSnackbar.showError(
        context,
        message:
            'Unable to post comment. Please check your network and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(postDetailControllerProvider(widget.postId));
    final authState = ref.watch(authControllerProvider);
    final currentUserId =
        authState is AuthAuthenticated ? authState.user.id : null;

    final post = state.post;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (post != null) ...[
            AppIconButton(
              icon: Icons.share_outlined,
              semanticLabel: 'Share post',
              onPressed: () => AppShareService.sharePost(context, post),
            ),
            if (currentUserId == post.authorId) ...[
              AppIconButton(
                icon: AppIcons.edit,
                semanticLabel: 'Edit post',
                onPressed: () async {
                  await context.push(
                    '/feed/posts/${post.id}/edit',
                    extra: post,
                  );
                  ref
                      .read(
                        postDetailControllerProvider(widget.postId).notifier,
                      )
                      .loadPostAndComments();
                },
              ),
              AppIconButton(
                icon: AppIcons.delete,
                semanticLabel: 'Delete post',
                onPressed: () async {
                  final router = GoRouter.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Post?'),
                      content: const Text(
                        'Are you sure you want to delete this post? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: AppColors.rose600),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    final deleted = await ref
                        .read(
                          postDetailControllerProvider(widget.postId).notifier,
                        )
                        .deletePost();
                    if (deleted && mounted) {
                      router.pop();
                      if (!context.mounted) return;
                      AppSnackbar.showSuccess(
                        context,
                        message: 'Post deleted successfully.',
                      );
                    }
                  }
                },
              ),
            ] else ...[
              AppIconButton(
                icon: AppIcons.report,
                semanticLabel: 'Report post',
                onPressed: () {
                  ReportContentDialog.show(
                    context,
                    targetId: post.id,
                    targetType: ReportType.post,
                  );
                },
              ),
            ],
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(context, state, isDark, currentUserId),
            ),
            _buildCommentInputBar(context, state, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PostDetailState state,
    bool isDark,
    String? currentUserId,
  ) {
    if (state.isLoadingPost && state.post == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            AppSkeleton(width: double.infinity, height: 160),
            AppSpacing.gapVMd,
            AppSkeleton(width: double.infinity, height: 80),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.post == null) {
      return Center(
        child: AppErrorState(
          title: 'Post unavailable',
          message: state.errorMessage!,
          onRetry: () {
            ref
                .read(postDetailControllerProvider(widget.postId).notifier)
                .loadPostAndComments();
          },
        ),
      );
    }

    final post = state.post!;

    return RefreshIndicator(
      onRefresh: () => ref
          .read(postDetailControllerProvider(widget.postId).notifier)
          .loadPostAndComments(),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Main Post Card
          PostCard(
            post: post,
            currentUserId: currentUserId,
            onLikePressed: () {
              ref
                  .read(postDetailControllerProvider(widget.postId).notifier)
                  .toggleLike();
            },
            onReportPressed: () {
              ReportContentDialog.show(
                context,
                targetId: post.id,
                targetType: ReportType.post,
              );
            },
          ),

          AppSpacing.gapVLg,

          // Comments Section Header
          Row(
            children: [
              Text(
                'Comments (${state.comments.length})',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.pureWhite : AppColors.slate900,
                ),
              ),
            ],
          ),

          AppSpacing.gapVMd,

          // Comments List
          if (state.isLoadingComments && state.comments.isEmpty) ...[
            const AppSkeleton(width: double.infinity, height: 64),
            AppSpacing.gapVSm,
            const AppSkeleton(width: double.infinity, height: 64),
          ] else if (state.comments.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppEmptyState(
                icon: AppIcons.comment,
                title: 'No comments yet',
                description:
                    'Be the first neighbor to reply and start the conversation!',
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.comments.length,
              separatorBuilder: (_, __) => AppSpacing.gapVSm,
              itemBuilder: (context, index) {
                final comment = state.comments[index];
                return _buildCommentTile(
                  context,
                  comment,
                  isDark,
                  currentUserId,
                );
              },
            ),
          ],

          if (state.isLoadingMoreComments) ...[
            AppSpacing.gapVMd,
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],

          AppSpacing.gapVXl,
        ],
      ),
    );
  }

  Widget _buildCommentTile(
    BuildContext context,
    CommentEntity comment,
    bool isDark,
    String? currentUserId,
  ) {
    final isAuthor = currentUserId != null && currentUserId == comment.authorId;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : const Color(0xFFECEEF5),
          width: 0.8,
        ),
        boxShadow: isDark ? null : AppElevation.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: comment.authorUsername != null &&
                        comment.authorUsername!.isNotEmpty
                    ? () => context.push('/@${comment.authorUsername}')
                    : null,
                child: AppAvatar(
                  name: comment.authorName,
                  imageUrl: comment.authorAvatarUrl,
                  size: AppAvatarSize.s24,
                ),
              ),
              AppSpacing.gapHSm,
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: comment.authorUsername != null &&
                                comment.authorUsername!.isNotEmpty
                            ? () => context.push('/@${comment.authorUsername}')
                            : null,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: comment.authorName,
                                style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (comment.authorHandle != null) ...[
                                TextSpan(
                                  text: ' · ${comment.authorHandle!}',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.darkPrimary
                                        : AppColors.lightPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (comment.authorLocality != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          comment.authorLocality!,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                comment.timeAgo,
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              if (isAuthor) ...[
                IconButton(
                  icon: const Icon(AppIcons.delete, size: 16),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Comment?'),
                        content: const Text(
                          'Are you sure you want to delete this comment?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppColors.rose600),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && mounted) {
                      await ref
                          .read(
                            postDetailControllerProvider(widget.postId)
                                .notifier,
                          )
                          .deleteComment(comment.id);
                    }
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(AppIcons.report, size: 16),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ReportContentDialog.show(
                      context,
                      targetId: comment.id,
                      targetType: ReportType.comment,
                    );
                  },
                ),
              ],
            ],
          ),
          AppSpacing.gapVSm,
          Text(
            comment.content,
            style: AppTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar(
    BuildContext context,
    PostDetailState state,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a neighborly reply...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.input,
                  borderSide: BorderSide(
                    color:
                        isDark ? AppColors.darkOutline : AppColors.lightOutline,
                  ),
                ),
              ),
              maxLines: null,
            ),
          ),
          AppSpacing.gapHSm,
          IconButton(
            icon: state.isSubmittingComment
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.send),
            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            onPressed: state.isSubmittingComment ? null : _submitComment,
          ),
        ],
      ),
    );
  }
}
