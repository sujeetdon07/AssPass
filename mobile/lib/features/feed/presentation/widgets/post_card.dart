import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../domain/entities/post_entity.dart';

/// Card widget rendering a single community feed post with header, content, and interactive actions.
class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    this.currentUserId,
    this.onTap,
    this.onLikePressed,
    this.onCommentPressed,
    this.onEditPressed,
    this.onDeletePressed,
    this.onReportPressed,
    super.key,
  });

  final PostEntity post;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLikePressed;
  final VoidCallback? onCommentPressed;
  final VoidCallback? onEditPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onReportPressed;

  bool get isAuthor => currentUserId != null && currentUserId == post.authorId;

  Color _categoryBadgeBg(PostCategory category, bool isDark) {
    switch (category) {
      case PostCategory.alert:
        return isDark
            ? AppColors.rose900.withValues(alpha: 0.3)
            : AppColors.rose50;
      case PostCategory.announcement:
        return isDark
            ? AppColors.amber900.withValues(alpha: 0.3)
            : AppColors.amber50;
      case PostCategory.question:
        return isDark
            ? AppColors.indigo900.withValues(alpha: 0.3)
            : AppColors.indigo50;
      case PostCategory.recommendation:
        return isDark
            ? AppColors.emerald900.withValues(alpha: 0.3)
            : AppColors.emerald50;
      case PostCategory.general:
        return isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainer;
    }
  }

  Color _categoryBadgeFg(PostCategory category, bool isDark) {
    switch (category) {
      case PostCategory.alert:
        return isDark ? AppColors.rose500 : AppColors.rose700;
      case PostCategory.announcement:
        return isDark ? AppColors.amber500 : AppColors.amber700;
      case PostCategory.question:
        return isDark ? AppColors.indigo300 : AppColors.indigo700;
      case PostCategory.recommendation:
        return isDark ? AppColors.emerald500 : AppColors.emerald700;
      case PostCategory.general:
        return isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Author info, Locality, Timestamp, Menu ─────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppAvatar(
                name: post.authorName,
                imageUrl: post.authorAvatarUrl,
                size: AppAvatarSize.s40,
              ),
              AppSpacing.gapHSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapHXxs,
                    Row(
                      children: [
                        Icon(
                          AppIcons.location,
                          size: 12,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            post.distance != null
                                ? '${post.distance} • ${post.locationDisplay}'
                                : post.locationDisplay,
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          post.timeAgo,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _categoryBadgeBg(post.category, isDark),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      post.category.icon,
                      size: 12,
                      color: _categoryBadgeFg(post.category, isDark),
                    ),
                    AppSpacing.gapHXxs,
                    Text(
                      post.category.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: _categoryBadgeFg(post.category, isDark),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Overflow Menu
              PopupMenuButton<String>(
                icon: Icon(
                  AppIcons.more,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEditPressed?.call();
                      break;
                    case 'delete':
                      onDeletePressed?.call();
                      break;
                    case 'report':
                      onReportPressed?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (isAuthor) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(AppIcons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Post'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.delete,
                            size: 18,
                            color: AppColors.rose600,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Post',
                            style: TextStyle(color: AppColors.rose600),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(AppIcons.report, size: 18),
                          SizedBox(width: 8),
                          Text('Report Post'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          AppSpacing.gapVMd,

          // ── Community Pill (if posted in a community) ──────────────────────
          if (post.communityName != null) ...[
            GestureDetector(
              onTap: () {
                if (post.communityId != null) {
                  context.push('/communities/${post.communityId}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo950.withValues(alpha: 0.5)
                      : AppColors.indigo50,
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: isDark ? AppColors.indigo800 : AppColors.indigo200,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.communities,
                      size: 13,
                      color: isDark ? AppColors.indigo300 : AppColors.indigo600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        post.communityName!,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.indigo300
                              : AppColors.indigo700,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.gapVSm,
          ],

          // ── Content ────────────────────────────────────────────────────────
          Text(
            post.content,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              height: 1.45,
            ),
          ),

          AppSpacing.gapVMd,

          // ── Actions: Like, Comment, Share ──────────────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
                : AppColors.lightOutlineVariant.withValues(alpha: 0.5),
          ),
          AppSpacing.gapVSm,

          Row(
            children: [
              // Like Action with optimistic feedback
              InkWell(
                onTap: onLikePressed,
                borderRadius: AppRadius.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        post.currentUserLiked
                            ? AppIcons.like
                            : AppIcons.likeOutline,
                        size: 20,
                        color: post.currentUserLiked
                            ? AppColors.rose600
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                      ),
                      AppSpacing.gapHXxs,
                      Text(
                        '${post.likeCount}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: post.currentUserLiked
                              ? AppColors.rose600
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              AppSpacing.gapHMd,

              // Comment Action
              InkWell(
                onTap: onCommentPressed ?? onTap,
                borderRadius: AppRadius.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.comment,
                        size: 20,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      AppSpacing.gapHXxs,
                      Text(
                        '${post.commentCount}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Share Action
              InkWell(
                onTap: () {
                  AppSnackbar.showInfo(
                    context,
                    message: 'Post link copied to clipboard.',
                  );
                },
                borderRadius: AppRadius.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Icon(
                    AppIcons.share,
                    size: 18,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
