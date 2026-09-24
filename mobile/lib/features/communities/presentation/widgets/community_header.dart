import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../domain/entities/community_category.dart';
import '../../domain/entities/community_entity.dart';

/// Top header banner and metadata card for CommunityDetailScreen.
class CommunityHeader extends StatelessWidget {
  const CommunityHeader({
    required this.community,
    required this.onJoinToggle,
    this.isLoadingJoin = false,
    this.onViewMembers,
    super.key,
  });

  final CommunityEntity community;
  final VoidCallback onJoinToggle;
  final bool isLoadingJoin;
  final VoidCallback? onViewMembers;

  Color _categoryColor(CommunityCategory category, bool isDark) {
    switch (category) {
      case CommunityCategory.society:
      case CommunityCategory.residents:
        return isDark ? AppColors.indigo400 : AppColors.indigo600;
      case CommunityCategory.localInterests:
      case CommunityCategory.hobbies:
        return isDark ? AppColors.violet400 : AppColors.violet600;
      case CommunityCategory.parentsFamily:
        return isDark ? AppColors.sky500 : AppColors.sky700;
      case CommunityCategory.students:
        return isDark ? AppColors.amber500 : AppColors.amber700;
      case CommunityCategory.localHelp:
        return isDark ? AppColors.teal400 : AppColors.teal600;
      case CommunityCategory.sports:
        return isDark ? AppColors.emerald500 : AppColors.emerald700;
      case CommunityCategory.neighborhood:
      case CommunityCategory.other:
        return isDark ? AppColors.slate400 : AppColors.slate600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = _categoryColor(community.category, isDark);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderLg,
                ),
                child: Icon(
                  community.category.icon,
                  color: catColor,
                  size: 30,
                ),
              ),
              AppSpacing.gapHMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapHXxs,
                    Row(
                      children: [
                        Icon(
                          AppIcons.location,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            community.locationDisplay,
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          AppSpacing.gapVMd,

          // Category & Privacy badges
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(community.category.icon, size: 13, color: catColor),
                    const SizedBox(width: 4),
                    Text(
                      community.category.label,
                      style: AppTypography.labelSmall.copyWith(
                        color: catColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: community.isPrivate
                      ? (isDark
                          ? AppColors.amber900.withValues(alpha: 0.3)
                          : AppColors.amber50)
                      : (isDark
                          ? AppColors.slate800
                          : AppColors.lightSurfaceContainerHigh),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      community.isPrivate ? AppIcons.lock : AppIcons.visibility,
                      size: 12,
                      color: community.isPrivate
                          ? (isDark ? AppColors.amber500 : AppColors.amber700)
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      community.isPrivate
                          ? 'Private Community'
                          : 'Public Community',
                      style: AppTypography.labelSmall.copyWith(
                        color: community.isPrivate
                            ? (isDark ? AppColors.amber500 : AppColors.amber700)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (community.currentUserRole != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.indigo900.withValues(alpha: 0.4)
                        : AppColors.indigo50,
                    borderRadius: AppRadius.chip,
                  ),
                  child: Text(
                    community.currentUserRole!.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark ? AppColors.indigo300 : AppColors.indigo700,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),

          AppSpacing.gapVMd,

          // Description
          Text(
            community.description,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              height: 1.45,
            ),
          ),

          AppSpacing.gapVMd,

          // Stats bar: Members (tappable) and Post count
          Row(
            children: [
              InkWell(
                onTap: onViewMembers,
                borderRadius: AppRadius.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xs,
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.communities,
                        size: 16,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${community.memberCount} ${community.memberCount == 1 ? 'member' : 'members'}',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.forward,
                        size: 14,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Icon(
                    AppIcons.comment,
                    size: 16,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${community.postCount} ${community.postCount == 1 ? 'post' : 'posts'}',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          AppSpacing.gapVMd,

          // Join / Leave Button
          AppButton(
            text: community.currentUserMember
                ? (community.isOwner ? 'Owner (Manage)' : 'Joined')
                : (community.isPrivate
                    ? 'Join Private Community'
                    : 'Join Community'),
            prefixIcon: community.currentUserMember
                ? (community.isOwner ? AppIcons.settings : AppIcons.check)
                : AppIcons.add,
            variant: community.currentUserMember
                ? AppButtonVariant.outlined
                : AppButtonVariant.primary,
            isLoading: isLoadingJoin,
            onPressed: onJoinToggle,
          ),
        ],
      ),
    );
  }
}
