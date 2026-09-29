import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/media/app_cached_image.dart';

class ChatPhotoViewer extends StatefulWidget {
  const ChatPhotoViewer({
    required this.imageUrl,
    this.thumbnailUrl,
    this.localImagePath,
    this.caption,
    this.heroTag,
    super.key,
  });

  final String imageUrl;
  final String? thumbnailUrl;
  final String? localImagePath;
  final String? caption;
  final String? heroTag;

  static void show(
    BuildContext context, {
    required String imageUrl,
    String? thumbnailUrl,
    String? localImagePath,
    String? caption,
    String? heroTag,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: AppColors.pureBlack.withValues(alpha: 0.95),
        pageBuilder: (context, _, __) => ChatPhotoViewer(
          imageUrl: imageUrl,
          thumbnailUrl: thumbnailUrl,
          localImagePath: localImagePath,
          caption: caption,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  State<ChatPhotoViewer> createState() => _ChatPhotoViewerState();
}

class _ChatPhotoViewerState extends State<ChatPhotoViewer>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late TapDownDetails _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLocal = widget.localImagePath != null &&
        widget.localImagePath!.isNotEmpty &&
        File(widget.localImagePath!).existsSync();

    Widget imageWidget;
    if (hasLocal) {
      imageWidget = Image.file(
        File(widget.localImagePath!),
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = AppCachedImage(
        imageUrl: widget.imageUrl,
        thumbnailUrl: widget.thumbnailUrl,
        fit: BoxFit.contain,
        borderRadius: BorderRadius.zero,
      );
    }

    if (widget.heroTag != null) {
      imageWidget = Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Zoom/Pan area
            GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              child: Center(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  clipBehavior: Clip.none,
                  child: imageWidget,
                ),
              ),
            ),

            // Top action bar
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.pureWhite),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.pureBlack.withValues(alpha: 0.5),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.pureWhite),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.pureBlack.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom caption (if present)
            if (widget.caption != null &&
                widget.caption!.trim().isNotEmpty &&
                widget.caption != 'Photo')
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.pureBlack.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.caption!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.pureWhite,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
