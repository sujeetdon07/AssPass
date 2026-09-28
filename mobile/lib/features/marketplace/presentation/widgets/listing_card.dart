import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_elevation.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/marketplace_listing_entity.dart';
import 'listing_status_chip.dart';

/// Reusable Marketplace Listing Card for grid and feed discovery.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.onFavoritePressed,
    this.showStatusAlways = false,
  });

  final MarketplaceListingEntity listing;
  final VoidCallback onTap;
  final VoidCallback? onFavoritePressed;
  final bool showStatusAlways;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor =
        isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: AppRadius.card,
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: isDark ? AppElevation.shadowDarkCard : AppElevation.shadowCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image / Visual Area ──────────────────────────────────────────
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (listing.primaryImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: listing.primaryImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildPlaceholder(isDark),
                      errorWidget: (_, __, ___) => _buildPlaceholder(isDark),
                    )
                  else
                    _buildPlaceholder(isDark),

                  // Sold Overlay
                  if (listing.isSold)
                    Container(
                      color: AppColors.pureBlack.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.slate900.withValues(alpha: 0.85),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: AppColors.pureWhite.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          'SOLD',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),

                  // Favorite Button
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Material(
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.8)
                          : AppColors.pureWhite.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onFavoritePressed,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            listing.isFavorited
                                ? AppIcons.like
                                : AppIcons.likeOutline,
                            size: 18,
                            color: listing.isFavorited
                                ? AppColors.rose500
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Condition Chip (Top Left)
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.darkSurface
                                : AppColors.pureWhite)
                            .withValues(alpha: 0.9),
                        borderRadius: AppRadius.borderSm,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pureBlack.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        listing.condition.label,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content Area ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price
                  Row(
                    children: [
                      Text(
                        listing.formattedPrice,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: listing.isFree
                              ? AppColors.emerald500
                              : primaryColor,
                        ),
                      ),
                      const Spacer(),
                      if (showStatusAlways || !listing.isActive)
                        ListingStatusChip(status: listing.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),

                  // Title
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Locality & Distance Row
                  Row(
                    children: [
                      Icon(
                        AppIcons.location,
                        size: 12,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Expanded(
                        child: Text(
                          listing.distance != null
                              ? '${listing.locality ?? listing.city ?? "Local"} • ${listing.distance}'
                              : (listing.locality ?? listing.city ?? 'Local'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                            fontSize: 11,
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
      ),
    ),
  );
}

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkSurfaceVariant : AppColors.indigo50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            listing.category.icon,
            size: 36,
            color: isDark ? AppColors.indigo300 : AppColors.indigo500,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            listing.category.label,
            style: AppTypography.labelSmall.copyWith(
              color: isDark ? AppColors.darkTextTertiary : AppColors.slate500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
