import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../buttons/app_button.dart';

/// Modal dialog providing interactive 1:1 square cropping for profile avatars.
///
/// Allows user to pan, zoom (pinch), and align their photo inside a fixed
/// 1:1 square crop box with optional circular preview guide.
class AppSquareCropDialog extends StatefulWidget {
  const AppSquareCropDialog({
    required this.imageFile,
    super.key,
  });

  final File imageFile;

  /// Convenience static helper to show the crop dialog.
  static Future<File?> show(BuildContext context, File imageFile) {
    return showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppSquareCropDialog(imageFile: imageFile),
    );
  }

  @override
  State<AppSquareCropDialog> createState() => _AppSquareCropDialogState();
}

class _AppSquareCropDialogState extends State<AppSquareCropDialog> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  bool _isProcessing = false;
  bool _showCircleGuide = true;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _onCropConfirmed() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary =
          _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Crop boundary not found.');
      }

      // Render square aperture to image
      // Target around 1024x1024 for high resolution
      final pixelRatio = (1024 / (boundary.size.width > 0 ? boundary.size.width : 300))
          .clamp(1.0, 4.0);

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode cropped image.');
      }

      final bytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final croppedFile = File(
        '${tempDir.path}/avatar_crop_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await croppedFile.writeAsBytes(bytes);

      if (mounted) {
        Navigator.of(context).pop(croppedFile);
      }
    } catch (e) {
      debugPrint('[AppSquareCropDialog] Crop error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to crop image. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cropBoxSize = (screenSize.width - 48).clamp(240.0, 360.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.pureWhite,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title & Preview guide toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Crop Profile Picture',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _showCircleGuide ? 'Hide circle guide' : 'Show circle guide',
                  icon: Icon(
                    _showCircleGuide ? Icons.radio_button_checked : Icons.crop_square,
                    size: 20,
                    color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  onPressed: () => setState(() => _showCircleGuide = !_showCircleGuide),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pinch to zoom and drag to reposition inside the 1:1 square frame.',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 1:1 Square Crop Viewport
            Center(
              child: ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: Container(
                  width: cropBoxSize,
                  height: cropBoxSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // RepaintBoundary capturing exact 1:1 square
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _cropAreaKey,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 1.0,
                            maxScale: 4.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: SizedBox(
                              width: cropBoxSize,
                              height: cropBoxSize,
                              child: Image.file(
                                widget.imageFile,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Optional Circle Guide Overlay
                      if (_showCircleGuide)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Cancel',
                    variant: AppButtonVariant.outlined,
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    text: 'Save Crop',
                    isLoading: _isProcessing,
                    onPressed: _onCropConfirmed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
