import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';

/// Available standard sizes for [AppAvatar].
enum AppAvatarSize {
  s24(24, 10, 14),
  s32(32, 12, 18),
  s40(40, 14, 22),
  s48(48, 16, 26),
  s56(56, 18, 30),
  s72(72, 24, 38);

  const AppAvatarSize(this.dimension, this.fontSize, this.iconSize);

  final double dimension;
  final double fontSize;
  final double iconSize;
}

/// Token-driven avatar component supporting images, initials, and fallback icons.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = AppAvatarSize.s40,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? name;
  final AppAvatarSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticLabel;

  String get _initials {
    if (name == null || name!.trim().isEmpty) return '';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = isDark
        ? AppColors.darkPrimaryContainer
        : const Color(0xFFE8EBFF);

    final defaultFg = isDark
        ? AppColors.darkOnPrimaryContainer
        : const Color(0xFF4338CA);

    final bg = backgroundColor ?? defaultBg;
    final fg = foregroundColor ?? defaultFg;

    Widget child;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildFallback(fg),
        errorWidget: (context, url, error) => _buildFallback(fg),
      );
    } else if (_initials.isNotEmpty) {
      child = Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: size.fontSize,
            fontWeight: FontWeight.w700,
            color: fg,
            letterSpacing: -0.2,
          ),
        ),
      );
    } else {
      child = _buildFallback(fg);
    }

    return Semantics(
      label: semanticLabel ?? name ?? 'User avatar',
      image: true,
      child: Container(
        width: size.dimension,
        height: size.dimension,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? AppColors.darkOutlineVariant
                : const Color(0xFFDCE2FF),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _buildFallback(Color fg) {
    return Center(
      child: Icon(
        AppIcons.profile,
        size: size.iconSize,
        color: fg,
      ),
    );
  }
}
