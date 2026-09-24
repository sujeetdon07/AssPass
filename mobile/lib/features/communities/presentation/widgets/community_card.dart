import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../domain/entities/community_category.dart';
import '../../domain/entities/community_entity.dart';

/// Card widget presenting a community summary in discovery lists and search results.
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    required this.community,
    this.onTap,
    this.onJoinToggle,
    this.isLoadingJoin = false,
    super.key,
  });

  final CommunityEntity community;
  final VoidCallback? onTap;
  final VoidCallback? onJoinToggle;
  final bool isLoadingJoin;

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

    return AppCard(
      onTap: onTap ?? () => context.push('/communities/${community.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Category icon, Name, Category chip & Privacy badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar / Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Icon(
                  community.category.icon,
                  color: catColor,
                  size: 24,
                ),
              ),
              AppSpacing.gapHSm,

              // Name & Location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: AppTypography.titleMedium.copyWith(
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
                          size: 13,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            community.locationDisplay,
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
                    ),
                  ],
                ),
              ),

              // Private Lock or Public badge
              if (community.isPrivate)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.amber900.withValues(alpha: 0.3)
                        : AppColors.amber50,
                    borderRadius: AppRadius.chip,
                    border: Border.all(
                      color: isDark ? AppColors.amber700 : AppColors.amber500,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.lock,
                        size: 11,
                        color: isDark ? AppColors.amber500 : AppColors.amber700,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Private',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppColors.amber500 : AppColors.amber700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          AppSpacing.gapVSm,

          // Description snippet
          Text(
            community.description,
            style: AppTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          AppSpacing.gapVMd,

          // Bottom bar: Counts + Action button
          Row(
            children: [
              // Member count
              Icon(
                AppIcons.communities,
                size: 15,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${community.memberCount} ${community.memberCount == 1 ? 'member' : 'members'}',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(width: 12),

              // Post count
              Icon(
                AppIcons.comment,
                size: 14,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                '${community.postCount} ${community.postCount == 1 ? 'post' : 'posts'}',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Join / Joined Button
              if (onJoinToggle != null)
                SizedBox(
                  height: 34,
                  child: community.currentUserMember
                      ? OutlinedButton.icon(
                          onPressed: onJoinToggle,
                          icon: const Icon(AppIcons.check, size: 14),
                          label: const Text(
                            'Joined',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.button,
                            ),
                          ),
                        )
                      : FilledButton(
                          onPressed: onJoinToggle,
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                            foregroundColor: isDark
                                ? AppColors.darkOnPrimary
                                : AppColors.lightOnPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadius.button,
                            ),
                          ),
                          child: const Text(
                            'Join',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
