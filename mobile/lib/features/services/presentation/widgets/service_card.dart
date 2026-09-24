import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../domain/entities/service_listing_entity.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    required this.service,
    this.onFavoriteToggle,
    super.key,
  });

  final ServiceListingEntity service;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      onTap: () => context.push('/services/${service.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Category Icon + Category Label + Favorite ─────────────
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkPrimary.withValues(alpha: 0.15)
                          : AppColors.lightPrimary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          service.category.icon,
                          size: 14,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        AppSpacing.gapHXxs,
                        Flexible(
                          child: Text(
                            service.category.label,
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AppSpacing.gapHXs,
              if (service.experienceYears != null &&
                  service.experienceYears! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerHigh
                        : AppColors.lightSurfaceContainer,
                    borderRadius: AppRadius.chip,
                  ),
                  child: Text(
                    '${service.experienceYears}y exp',
                    style: AppTypography.labelSmall.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                AppSpacing.gapHXs,
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onFavoriteToggle,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    service.isFavorited ? AppIcons.like : AppIcons.likeOutline,
                    size: 18,
                    color: service.isFavorited
                        ? AppColors.rose500
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapVSm,

          // ── Title ──────────────────────────────────────────────────────────
          Text(
            service.title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapVXs,

          // ── Description ────────────────────────────────────────────────────
          Text(
            service.description,
            style: AppTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.gapVSm,

          // ── Provider info ──────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceContainer,
                backgroundImage: service.provider.avatarUrl != null
                    ? NetworkImage(service.provider.avatarUrl!)
                    : null,
                child: service.provider.avatarUrl == null
                    ? Text(
                        service.provider.displayName.isNotEmpty
                            ? service.provider.displayName[0].toUpperCase()
                            : 'N',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                      )
                    : null,
              ),
              AppSpacing.gapHXs,
              Expanded(
                child: Text(
                  service.businessName != null &&
                          service.businessName!.isNotEmpty
                      ? '${service.provider.displayName} • ${service.businessName}'
                      : service.provider.displayName,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          AppSpacing.gapVSm,

          const Divider(height: 1),
          AppSpacing.gapVSm,

          // ── Bottom: Price & Location ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Price
              Flexible(
                child: Text(
                  service.formattedPrice,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              AppSpacing.gapHSm,

              // Locality & Distance
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.location,
                      size: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    AppSpacing.gapHXxs,
                    Flexible(
                      child: Text(
                        service.distance != null
                            ? '${service.locationSummary} • ${service.distance}'
                            : service.locationSummary,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
