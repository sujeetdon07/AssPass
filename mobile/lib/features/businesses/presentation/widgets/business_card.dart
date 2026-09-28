import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../domain/entities/business_entity.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    required this.business,
    this.onFavoriteToggle,
    super.key,
  });

  final BusinessEntity business;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryImage = business.primaryImageUrl;
    final status = business.operatingStatus;

    Color statusColor;
    Color statusBgColor;
    if (status.isOpen) {
      if (status.status == 'closes_later') {
        statusColor = isDark ? Colors.amber[300]! : Colors.amber[800]!;
        statusBgColor = isDark
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.amber.withValues(alpha: 0.12);
      } else {
        statusColor = isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
        statusBgColor = isDark
            ? AppColors.darkSuccess.withValues(alpha: 0.15)
            : AppColors.lightSuccess.withValues(alpha: 0.12);
      }
    } else {
      statusColor = isDark ? AppColors.darkTextSecondary : AppColors.slate500;
      statusBgColor = isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurfaceContainer;
    }

    return AppCard(
      onTap: () => context.push('/businesses/${business.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover Image / Placeholder ──────────────────────────────────────
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.lightSurfaceContainer,
                  child: primaryImage != null
                      ? CachedNetworkImage(
                          imageUrl: primaryImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: isDark
                                ? AppColors.darkSurfaceContainerHigh
                                : AppColors.lightSurfaceContainer,
                          ),
                          errorWidget: (context, error, stackTrace) =>
                              _buildCategoryPlaceholder(isDark),
                        )
                      : _buildCategoryPlaceholder(isDark),
                ),
              ),

              // Category Badge
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.slate900.withValues(alpha: 0.85)
                        : AppColors.pureWhite.withValues(alpha: 0.92),
                    borderRadius: AppRadius.chip,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        business.category.icon,
                        size: 13,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      AppSpacing.gapHXxs,
                      Text(
                        business.category.label,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Favorite Button
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onFavoriteToggle,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.slate900.withValues(alpha: 0.8)
                          : AppColors.pureWhite.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      business.isFavorited
                          ? AppIcons.like
                          : AppIcons.likeOutline,
                      size: 18,
                      color: business.isFavorited
                          ? AppColors.rose500
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Details ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business Name & Verification
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        business.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (business.verificationStatus ==
                        BusinessVerificationStatus.verified) ...[
                      AppSpacing.gapHXs,
                      const Icon(
                        AppIcons.verified,
                        size: 16,
                        color: AppColors.indigo600,
                      ),
                    ],
                  ],
                ),
                AppSpacing.gapVXs,

                // Description
                Text(
                  business.description,
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.gapVSm,

                // Locality & Distance
                Row(
                  children: [
                    Icon(
                      AppIcons.location,
                      size: 14,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                    AppSpacing.gapHXxs,
                    Expanded(
                      child: Text(
                        business.distance != null
                            ? '${business.locationSummary} • ${business.distance}'
                            : business.locationSummary,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapVSm,

                // Operating Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: AppRadius.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      AppSpacing.gapHXs,
                      Text(
                        status.statusText,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPlaceholder(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            business.category.icon,
            size: 40,
            color: isDark
                ? AppColors.darkTextSecondary.withValues(alpha: 0.5)
                : AppColors.lightTextSecondary.withValues(alpha: 0.5),
          ),
          AppSpacing.gapVXs,
          Text(
            business.category.label,
            style: AppTypography.labelSmall.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary.withValues(alpha: 0.7)
                  : AppColors.lightTextSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
