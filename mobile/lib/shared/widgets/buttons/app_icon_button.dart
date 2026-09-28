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
    this.minTouchTarget = 48.0,
    this.badgeCount,
    this.color,
    this.padding,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final AppIconButtonVariant variant;
  final double iconSize;
  final double minTouchTarget;
  final int? badgeCount;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPadding = minTouchTarget < 48.0
        ? EdgeInsets.zero
        : const EdgeInsets.all(8.0);
    final resolvedPadding = padding ?? defaultPadding;

    Widget button;

    switch (variant) {
      case AppIconButtonVariant.standard:
        button = IconButton(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          padding: resolvedPadding,
          constraints: BoxConstraints(
            minWidth: minTouchTarget,
            minHeight: minTouchTarget,
          ),
          style: IconButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: Size(minTouchTarget, minTouchTarget),
            tapTargetSize: minTouchTarget < 48.0
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            visualDensity: minTouchTarget < 48.0
                ? VisualDensity.compact
                : VisualDensity.standard,
          ),
          color: color ??
              (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        );
      case AppIconButtonVariant.filled:
        button = IconButton.filled(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          padding: resolvedPadding,
          style: IconButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: Size(minTouchTarget, minTouchTarget),
            tapTargetSize: minTouchTarget < 48.0
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            backgroundColor:
                isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            foregroundColor: color ??
                (isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
      case AppIconButtonVariant.tonal:
        button = IconButton.filledTonal(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          padding: resolvedPadding,
          style: IconButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: Size(minTouchTarget, minTouchTarget),
            tapTargetSize: minTouchTarget < 48.0
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            backgroundColor: isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurfaceContainer,
            foregroundColor: color ??
                (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
      case AppIconButtonVariant.outlined:
        button = IconButton.outlined(
          icon: _buildIconWithBadge(isDark),
          onPressed: onPressed,
          tooltip: semanticLabel,
          iconSize: iconSize,
          padding: resolvedPadding,
          style: IconButton.styleFrom(
            padding: resolvedPadding,
            minimumSize: Size(minTouchTarget, minTouchTarget),
            tapTargetSize: minTouchTarget < 48.0
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            side: BorderSide(
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            ),
            foregroundColor: color,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
        );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTouchTarget,
          minHeight: minTouchTarget,
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
