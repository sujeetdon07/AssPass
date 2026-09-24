import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/location_state.dart';

/// Informative header badge displaying the current location mode and a button to switch locality.
class LocationHeaderBadge extends StatelessWidget {
  const LocationHeaderBadge({
    super.key,
    required this.locationState,
    required this.onChangeLocality,
  });

  final LocationState locationState;
  final VoidCallback onChangeLocality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isCurrentLocation = locationState is LocationReady;
    final isManual = locationState is LocationManualLocality;

    String title;
    String subtitle;
    IconData icon;
    Color iconColor;

    if (isCurrentLocation) {
      final ready = locationState as LocationReady;
      title = 'Near your current location';
      subtitle = ready.isApproximate
          ? 'Approximate device location'
          : 'Precise GPS position';
      icon = AppIcons.location;
      iconColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    } else if (isManual) {
      final manual = locationState as LocationManualLocality;
      title = 'Near ${manual.displayName}';
      subtitle = 'Using selected locality';
      icon = AppIcons.communities;
      iconColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    } else {
      title = 'Nearby Discovery';
      subtitle = 'Location required';
      icon = AppIcons.location;
      iconColor =
          isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.lightSurfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          AppSpacing.gapHSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeLocality,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: const Size(50, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Change',
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
