import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../domain/models/notification_item.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categoryColor = _getCategoryColor(item.category);
    final categoryIcon = _getCategoryIcon(item.type, item.category);

    final unreadBg = isDark
        ? AppColors.indigo950.withValues(alpha: 0.35)
        : AppColors.indigo50.withValues(alpha: 0.55);

    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: AppColors.rose500,
        child: const Icon(
          AppIcons.delete,
          color: AppColors.pureWhite,
          size: 24,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: item.isRead ? Colors.transparent : unreadBg,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.slate800 : AppColors.slate100,
                width: 1,
              ),
              left: !item.isRead
                  ? const BorderSide(color: AppColors.indigo600, width: 3.5)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar or Category Icon
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (item.sender != null && item.sender!.displayName != null)
                    AppAvatar(
                      name: item.sender!.displayName,
                      imageUrl: item.sender!.avatarUrl,
                      size: AppAvatarSize.s40,
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 20,
                      ),
                    ),
                  // Category badge overlay when sender avatar is present
                  if (item.sender != null && item.sender!.displayName != null)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: categoryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.slate900
                                : AppColors.pureWhite,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          categoryIcon,
                          color: AppColors.pureWhite,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),

              // Content: Title, Body, Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: isDark
                                  ? AppColors.slate100
                                  : AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _formatTimeAgo(item.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Unread dot
              if (!item.isRead) ...[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.indigo600,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.messages:
        return AppColors.indigo600;
      case NotificationCategory.social:
        return AppColors.rose500;
      case NotificationCategory.community:
        return AppColors.teal600;
      case NotificationCategory.marketplace:
        return AppColors.amber500;
      case NotificationCategory.business:
        return AppColors.violet600;
      case NotificationCategory.system:
        return AppColors.slate600;
    }
  }

  IconData _getCategoryIcon(
    NotificationType type,
    NotificationCategory category,
  ) {
    switch (type) {
      case NotificationType.messageReceived:
        return AppIcons.chat;
      case NotificationType.postLiked:
        return AppIcons.like;
      case NotificationType.postCommented:
      case NotificationType.commentReplied:
        return AppIcons.comment;
      case NotificationType.communityMembership:
      case NotificationType.communityAnnouncement:
        return AppIcons.communities;
      case NotificationType.marketplaceActivity:
        return AppIcons.marketplace;
      case NotificationType.businessActivity:
        return AppIcons.business;
      case NotificationType.system:
        return AppIcons.info;
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
