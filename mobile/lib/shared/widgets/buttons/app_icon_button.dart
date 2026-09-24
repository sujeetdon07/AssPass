import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

enum AppIconButtonVariant {
  standard,
  filled,
  tonal,
  outlined,
}

/// Accessible icon button honoring minimum 48px touch targets.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.variant = AppIconButtonVariant.standard,
    this.iconSize = 24.0,
    this.badgeCount,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final AppIconButtonVariant variant;
  final double iconSize;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget button;

    switch (variant) {
      case AppIconButtonVariant.standard:
        button = IconButton(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          color:
              isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        );
      case AppIconButtonVariant.filled:
        button = IconButton.filled(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          style: IconButton.styleFrom(
            backgroundColor:
                isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            foregroundColor:
                isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
      case AppIconButtonVariant.tonal:
        button = IconButton.filledTonal(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainer,
            foregroundColor:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
      case AppIconButtonVariant.outlined:
        button = IconButton.outlined(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          style: IconButton.styleFrom(
            side: BorderSide(
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        child: button,
      ),
    );
  }

  Widget _buildIconWithBadge(bool isDark) {
    if (badgeCount == null || badgeCount! <= 0) {
      return Icon(icon, size: iconSize);
    }

    return Badge(
      label: Text(
        badgeCount! > 99 ? '99+' : '$badgeCount',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: AppColors.lightError,
      child: Icon(icon, size: iconSize),
    );
  }
}
