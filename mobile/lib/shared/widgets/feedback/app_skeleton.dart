import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';

/// Loading skeleton primitive for content placeholders.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.borderSm,
    this.isCircle = false,
  });

  const AppSkeleton.line({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.borderXs,
  }) : isCircle = false;

  const AppSkeleton.circle({
    super.key,
    double size = 40,
  })  : width = size,
        height = size,
        borderRadius = AppRadius.borderPill,
        isCircle = true;

  const AppSkeleton.card({
    super.key,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius = AppRadius.card,
  }) : isCircle = false;

  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final bool isCircle;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (!const bool.fromEnvironment('flutter.test')) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.isCircle ? null : widget.borderRadius,
            ),
          ),
        );
      },
    );
  }
}

/// Helper to render a group of skeleton lines mimicking a paragraph.
class AppSkeletonParagraph extends StatelessWidget {
  const AppSkeletonParagraph({
    super.key,
    this.lines = 3,
  });

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
          child: AppSkeleton.line(
            width: isLast ? 160 : double.infinity,
          ),
        );
      }),
    );
  }
}
