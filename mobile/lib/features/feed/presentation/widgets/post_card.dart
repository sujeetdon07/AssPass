import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../core/services/app_share_service.dart';
import '../../domain/entities/post_entity.dart';
import 'mentions/mention_text_view.dart';

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
      borderRadius: BorderRadius.circular(24.0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Author info, Locality, Timestamp, Menu ─────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: post.authorUsername != null &&
                        post.authorUsername!.isNotEmpty
                    ? () => context.push('/@${post.authorUsername}')
                    : null,
                child: AppAvatar(
                  name: post.authorName,
                  imageUrl: post.authorAvatarUrl,
                  size: AppAvatarSize.s40,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top line: Author Name + Category Badge + 3 dots
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: post.authorUsername != null &&
                                    post.authorUsername!.isNotEmpty
                                ? () => context.push('/@${post.authorUsername}')
                                : null,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: post.authorName,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  if (post.authorHandle != null) ...[
                                    TextSpan(
                                      text: ' · ${post.authorHandle!}',
                                      style: AppTypography.labelSmall.copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12.5,
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
                        const SizedBox(width: 6),

                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryBadgeBg(post.category, isDark),
                            borderRadius: AppRadius.chip,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutlineVariant
                                  : const Color(0xFFE2E8F0),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                post.category.icon,
                                size: 12,
                                color: _categoryBadgeFg(post.category, isDark),
                              ),
                              const SizedBox(width: 4),
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
                        const SizedBox(width: 6),

                        // Overflow Menu Button
                        Transform.translate(
                          offset: const Offset(8, 0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.slate400,
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
                                case 'share':
                                  AppShareService.sharePost(context, post);
                                  break;
                                case 'send_in_aaspaas':
                                  AppShareService.showSendInAaspaasSheet(
                                    context,
                                    AppShareService.buildPostPayload(post),
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Share via...'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'send_in_aaspaas',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      size: 18,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Send in Aaspaas'),
                                  ],
                                ),
                              ),
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
                        ),
                      ),
                    ],
                  ),

                    const SizedBox(height: 3),

                    // Second line: Location pin + Locality + Bullet + Time ago
                    Row(
                      children: [
                        Icon(
                          AppIcons.location,
                          size: 12,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.slate400,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            post.distance != null
                                ? '${post.distance} • ${post.locationDisplay}'
                                : post.locationDisplay,
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.slate500,
                              fontWeight: FontWeight.w500,
                              fontSize: 11.5,
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
                                  : AppColors.slate400,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          post.timeAgo,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.slate400,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Community Pill (if posted in a community) ──────────────────────
          if (post.communityName != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (post.communityId != null) {
                  context.push('/communities/${post.communityId}');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo950.withValues(alpha: 0.5)
                      : const Color(0xFFF0F3FF),
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: isDark
                        ? AppColors.indigo800
                        : const Color(0xFFDCE2FE),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.communities,
                      size: 13,
                      color: isDark ? AppColors.indigo300 : const Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        post.communityName!,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.indigo300
                              : const Color(0xFF4338CA),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Content ────────────────────────────────────────────────────────
          MentionTextView(
            text: post.content,
            mentions: post.mentions,
          ),

          const SizedBox(height: 14),

          // ── Subtle divider separating post body from actions ───────────────
          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark
                ? AppColors.darkOutlineVariant
                : const Color(0xFFECEEF2),
          ),

          const SizedBox(height: 4),

          // ── Actions: Like, Comment, Share ──────────────────────────────────
          Row(
            children: [
              // Like Action with optimistic feedback
              InkWell(
                onTap: onLikePressed,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        post.currentUserLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: post.currentUserLiked
                            ? const Color(0xFF4F46E5)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.slate500),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.likeCount}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: post.currentUserLiked
                              ? const Color(0xFF4F46E5)
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.slate700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Comment Action
              InkWell(
                onTap: onCommentPressed ?? onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.slate500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post.commentCount}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Share Action
              Transform.translate(
                offset: const Offset(6, 0),
                child: InkWell(
                  onTap: () {
                    AppShareService.sharePost(context, post);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      size: 19,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.slate500,
                    ),
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
