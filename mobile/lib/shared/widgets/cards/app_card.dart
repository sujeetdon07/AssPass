import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

enum AppCardVariant {
  standard,
  compact,
  outlined,
  elevated,
}

/// Token-driven card container for Aaspaas.
///
/// Supports interactive touch feedback, custom padding, and variants.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.variant = AppCardVariant.standard,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final AppCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedPadding = padding ??
        (variant == AppCardVariant.compact
            ? AppSpacing.cardPaddingCompact
            : AppSpacing.cardPadding);

    final resolvedBgColor = backgroundColor ??
        (variant == AppCardVariant.elevated
            ? (isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurface)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface));

    final resolvedBorderColor = borderColor ??
        (variant == AppCardVariant.outlined
            ? (isDark ? AppColors.darkOutline : AppColors.lightOutline)
            : (isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant));

    final List<BoxShadow>? resolvedShadow;
    switch (variant) {
      case AppCardVariant.standard:
      case AppCardVariant.elevated:
        resolvedShadow = isDark
            ? AppElevation.shadowDarkCard
            : AppElevation.shadowCard;
        break;
      case AppCardVariant.compact:
        resolvedShadow = isDark ? null : AppElevation.shadowSm;
        break;
      case AppCardVariant.outlined:
        resolvedShadow = null;
        break;
    }

    final resolvedRadius = borderRadius ?? AppRadius.cardClay;

    final decoration = BoxDecoration(
      color: resolvedBgColor,
      borderRadius: resolvedRadius,
      border: Border.all(
        color: resolvedBorderColor,
        width: 0.8,
      ),
      boxShadow: resolvedShadow,
    );

    Widget content = Padding(
      padding: resolvedPadding,
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: AppColors.transparent,
        borderRadius: resolvedRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: resolvedRadius,
          splashColor: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              .withValues(alpha: 0.08),
          highlightColor: (isDark ? AppColors.darkPrimary : AppColors.lightPrimary)
              .withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    Widget card = Container(
      decoration: decoration,
      child: content,
    );

    if (semanticLabel != null) {
      card = Semantics(
        container: true,
        label: semanticLabel,
        button: onTap != null,
        child: card,
      );
    }

    return card;
  }
}
