import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/media/app_cached_image.dart';
import '../../../../shared/widgets/media/app_photo_gallery_viewer.dart';
import '../../domain/entities/post_image_entity.dart';

/// Horizontal swipe carousel for Feed post images (1 to 4 images).
///
/// Features:
/// - Smooth [PageView] with native physics and page snapping.
/// - Stable bounded aspect-ratio container preventing post card height jumps.
/// - Modern Claymorphic page indicator dots for multi-image posts.
/// - Tap to open [AppPhotoGalleryViewer] at the active page index.
/// - Full accessibility semantics ("Photo X of Y").
/// - Graceful handling of legacy multi-image posts (>4 images).
class PostMediaCarousel extends StatefulWidget {
  const PostMediaCarousel({
    required this.images,
    this.onImageTap,
    super.key,
  });

  final List<PostImageEntity> images;
  final void Function(int index)? onImageTap;

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleImageTap(int index) {
    if (widget.onImageTap != null) {
      widget.onImageTap!(index);
    } else {
      AppPhotoGalleryViewer.show(
        context,
        imageUrls: widget.images.map((img) => img.url).toList(),
        thumbnailUrls: widget.images
            .map((img) => img.thumbnailUrl ?? img.url)
            .toList(),
        initialIndex: index,
      );
    }
  }

  /// Calculates a stable aspect ratio for the carousel viewport.
  /// For single image: uses image aspect ratio clamped between [0.8, 1.8].
  /// For multiple images: uses a consistent 4:3 (1.33) ratio or first image's
  /// clamped ratio to guarantee zero card jumping during swipe.
  double _calculateAspectRatio() {
    if (widget.images.isEmpty) return 4 / 3;

    final firstImage = widget.images.first;
    if (firstImage.aspectRatio != null && firstImage.aspectRatio! > 0) {
      // Clamp between portrait 4:5 (0.8) and wide 16:9 (1.78)
      return firstImage.aspectRatio!.clamp(0.8, 1.78);
    }

    return 4 / 3;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final isSingle = widget.images.length == 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aspectRatio = _calculateAspectRatio();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Carousel Viewport Container ─────────────────────────────────────
        Semantics(
          label: isSingle
              ? 'Attached photo'
              : 'Photo ${_currentIndex + 1} of ${widget.images.length}',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView for swipeable images
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    pageSnapping: true,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final image = widget.images[index];
                      // Use medium variant for feed card performance
                      final displayUrl = image.mediumUrl ?? image.url;

                      return GestureDetector(
                        onTap: () => _handleImageTap(index),
                        child: AppCachedImage(
                          imageUrl: displayUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      );
                    },
                  ),

                  // Floating Counter Pill (top-right) for multi-image posts
                  if (!isSingle)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pureBlack.withValues(alpha: 0.55),
                          borderRadius: AppRadius.borderPill,
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${widget.images.length}',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),

        // ── Modern Indicator Dots (Only for 2+ images) ──────────────────────
        if (!isSingle) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) {
                final isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isActive
                        ? (isDark ? AppColors.indigo400 : AppColors.indigo600)
                        : (isDark
                            ? AppColors.darkOutlineVariant.withValues(alpha: 0.6)
                            : AppColors.lightOutlineVariant),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
