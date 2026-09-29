import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'app_cached_image.dart';

/// Full-screen photo gallery viewer supporting multi-image swiping,
/// pinch-to-zoom, double-tap zoom, and high-resolution rendering.
class AppPhotoGalleryViewer extends StatefulWidget {
  const AppPhotoGalleryViewer({
    required this.imageUrls,
    this.initialIndex = 0,
    this.thumbnailUrls,
    this.title,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final List<String>? thumbnailUrls;
  final String? title;

  static void show(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    List<String>? thumbnailUrls,
    String? title,
  }) {
    if (imageUrls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: AppColors.pureBlack.withValues(alpha: 0.95),
        pageBuilder: (context, _, __) => AppPhotoGalleryViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
          thumbnailUrls: thumbnailUrls,
          title: title,
        ),
      ),
    );
  }

  @override
  State<AppPhotoGalleryViewer> createState() => _AppPhotoGalleryViewerState();
}

class _AppPhotoGalleryViewerState extends State<AppPhotoGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Swipeable image pages
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final url = widget.imageUrls[index];
                final thumb = widget.thumbnailUrls != null &&
                        index < widget.thumbnailUrls!.length
                    ? widget.thumbnailUrls![index]
                    : null;
                return _ZoomableImagePage(imageUrl: url, thumbnailUrl: thumb);
              },
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
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.pureWhite,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppColors.pureBlack.withValues(alpha: 0.5),
                    ),
                  ),
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.pureBlack.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  IconButton.filled(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.pureWhite,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppColors.pureBlack.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Optional title at bottom
            if (widget.title != null && widget.title!.trim().isNotEmpty)
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
                    widget.title!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

class _ZoomableImagePage extends StatefulWidget {
  const _ZoomableImagePage({
    required this.imageUrl,
    this.thumbnailUrl,
  });

  final String imageUrl;
  final String? thumbnailUrl;

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
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
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          clipBehavior: Clip.none,
          child: AppCachedImage(
            imageUrl: widget.imageUrl,
            thumbnailUrl: widget.thumbnailUrl,
            fit: BoxFit.contain,
            borderRadius: BorderRadius.zero,
          ),
        ),
      ),
    );
  }
}
