import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Supported visual variants for [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  tonal,
  outlined,
  text,
  destructive,
}

/// Accessible, responsive, and token-driven button component for Aaspaas.
///
/// Features:
/// - Enforces minimum 48px touch target for accessibility.
/// - Supports loading state with accessible progress indicator.
/// - Prevents duplicate taps when loading or disabled.
/// - Adheres strictly to Aaspaas design tokens.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.prefixIcon,
    this.suffixIcon,
    this.isFullWidth = true,
    this.semanticLabel,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isFullWidth;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final childContent = _buildContent(theme, isDark);

    final buttonStyle = _resolveStyle(theme, isDark);

    Widget button;
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.tonal:
      case AppButtonVariant.destructive:
        button = FilledButton(
          onPressed: _isEnabled ? onPressed : null,
          style: buttonStyle,
          child: childContent,
        );
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: _isEnabled ? onPressed : null,
          style: buttonStyle,
          child: childContent,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: _isEnabled ? onPressed : null,
          style: buttonStyle,
          child: childContent,
        );
    }

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: semanticLabel ?? text,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 48,
          minWidth: isFullWidth ? double.infinity : 0,
        ),
        child: button,
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    if (isLoading) {
      final spinnerColor = _resolveForegroundColor(theme, isDark);
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
        ),
      );
    }

    final children = <Widget>[];

    if (prefixIcon != null) {
      children.add(Icon(prefixIcon, size: 20));
      children.add(AppSpacing.gapHSm);
    }

    children.add(
      Text(
        text,
        style: AppTypography.labelLarge,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (suffixIcon != null) {
      children.add(AppSpacing.gapHSm);
      children.add(Icon(suffixIcon, size: 20));
    }

    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Color _resolveForegroundColor(ThemeData theme, bool isDark) {
    if (!_isEnabled) {
      return isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled;
    }
    return switch (variant) {
      AppButtonVariant.primary =>
        isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
      AppButtonVariant.secondary => isDark
          ? AppColors.darkOnSecondaryContainer
          : AppColors.lightOnSecondaryContainer,
      AppButtonVariant.tonal => isDark
          ? AppColors.darkOnPrimaryContainer
          : AppColors.lightOnPrimaryContainer,
      AppButtonVariant.outlined ||
      AppButtonVariant.text =>
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
      AppButtonVariant.destructive => AppColors.pureWhite,
    };
  }

  ButtonStyle _resolveStyle(ThemeData theme, bool isDark) {
    switch (variant) {
      case AppButtonVariant.primary:
        return FilledButton.styleFrom(
          backgroundColor:
              isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          foregroundColor:
              isDark ? AppColors.darkOnPrimary : AppColors.lightOnPrimary,
          disabledBackgroundColor: isDark
              ? AppColors.darkSurfaceContainerHigh
              : AppColors.lightSurfaceContainerHigh,
          disabledForegroundColor:
              isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.s12,
          ),
        );

      case AppButtonVariant.secondary:
        return FilledButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.darkSecondaryContainer
              : AppColors.lightSecondaryContainer,
          foregroundColor: isDark
              ? AppColors.darkOnSecondaryContainer
              : AppColors.lightOnSecondaryContainer,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.s12,
          ),
        );

      case AppButtonVariant.tonal:
        return FilledButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.darkPrimaryContainer
              : AppColors.lightPrimaryContainer,
          foregroundColor: isDark
              ? AppColors.darkOnPrimaryContainer
              : AppColors.lightOnPrimaryContainer,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.s12,
          ),
        );

      case AppButtonVariant.outlined:
        return OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          side: BorderSide(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.s12,
          ),
        );

      case AppButtonVariant.text:
        return TextButton.styleFrom(
          foregroundColor:
              isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        );

      case AppButtonVariant.destructive:
        return FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkError : AppColors.lightError,
          foregroundColor: AppColors.pureWhite,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.s12,
          ),
        );
    }
  }
}
