import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../domain/entities/location_state.dart';

/// Full-screen or container view handling all permission, service disabled, and fallback states.
class NearbyPermissionView extends StatelessWidget {
  const NearbyPermissionView({
    super.key,
    required this.locationState,
    required this.onRequestLocation,
    required this.onChooseLocality,
    required this.onOpenSettings,
    required this.onOpenLocationSettings,
  });

  final LocationState locationState;
  final VoidCallback onRequestLocation;
  final VoidCallback onChooseLocality;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (locationState is LocationRequestingPermission ||
        locationState is LocationAcquiring) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            AppSpacing.gapVMd,
            Text(
              locationState is LocationRequestingPermission
                  ? 'Requesting location permission...'
                  : 'Acquiring location fix...',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    IconData icon = AppIcons.location;
    String title = "Discover What's Around You";
    String description =
        'Aaspaas uses your location to discover posts, community alerts, and neighbors in your immediate vicinity. Your exact address is never shared.';
    String primaryButtonLabel = 'Enable Location';
    VoidCallback primaryAction = onRequestLocation;

    if (locationState is LocationPermissionDenied) {
      icon = AppIcons.location;
      title = 'Location Permission Needed';
      description =
          'Nearby discovery needs location access to calculate distance to community posts. You can also pick a locality manually.';
      primaryButtonLabel = 'Allow Location';
      primaryAction = onRequestLocation;
    } else if (locationState is LocationPermissionPermanentlyDenied) {
      icon = Icons.settings_outlined;
      title = 'Permission Permanently Disabled';
      description =
          'Location access is permanently disabled for Aaspaas. Please enable it in device settings, or select a locality manually.';
      primaryButtonLabel = 'Open App Settings';
      primaryAction = onOpenSettings;
    } else if (locationState is LocationServiceDisabled) {
      icon = Icons.location_off_outlined;
      title = 'Location Services Turned Off';
      description =
          'Your device location (GPS) is turned off. Please enable location services in your system settings, or choose a locality.';
      primaryButtonLabel = 'Turn On Location';
      primaryAction = onOpenLocationSettings;
    } else if (locationState is LocationError) {
      final error = locationState as LocationError;
      icon = Icons.error_outline_rounded;
      title = 'Location Detection Failed';
      description = error.message;
      primaryButtonLabel = 'Try Again';
      primaryAction = onRequestLocation;
    }

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppSpacing.gapVXxl,
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: primaryColor,
                ),
              ),
              AppSpacing.gapVLg,
              Text(
                title,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVSm,
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapVXxl,
              AppButton(
                text: primaryButtonLabel,
                onPressed: primaryAction,
                isFullWidth: true,
              ),
              AppSpacing.gapVMd,
              AppButton(
                text: 'Choose Locality Instead',
                variant: AppButtonVariant.outlined,
                onPressed: onChooseLocality,
                isFullWidth: true,
              ),
              AppSpacing.gapVLg,
            ],
          ),
        ),
      ),
    );
  }
}
