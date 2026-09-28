import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/app_media_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Claymorphic single image picker for cover photos and banners.
class AppSingleImagePicker extends ConsumerStatefulWidget {
  const AppSingleImagePicker({
    this.initialUrl,
    required this.onUrlChanged,
    this.label = 'Cover Image',
    this.category = 'content',
    this.aspectRatio = 16 / 9,
    super.key,
  });

  final String? initialUrl;
  final ValueChanged<String?> onUrlChanged;
  final String label;
  final String category;
  final double aspectRatio;

  @override
  ConsumerState<AppSingleImagePicker> createState() => _AppSingleImagePickerState();
}

class _AppSingleImagePickerState extends ConsumerState<AppSingleImagePicker> {
  File? _localFile;
  String? _remoteUrl;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _remoteUrl = widget.initialUrl;
  }

  Future<void> _pickImage() async {
    setState(() => _errorMessage = null);

    try {
      final mediaService = ref.read(appMediaServiceProvider);
      final file = await mediaService.pickSingleImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() {
        _localFile = file;
        _isUploading = true;
      });

      final result = await mediaService.uploadImage(file, type: widget.category);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _remoteUrl = result.url;
        });
        widget.onUrlChanged(result.url);
      }
    } catch (e) {
      debugPrint('[AppSingleImagePicker] Upload error: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed. Tap to retry.';
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _localFile = null;
      _remoteUrl = null;
      _errorMessage = null;
    });
    widget.onUrlChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = _localFile != null || (_remoteUrl != null && _remoteUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            if (hasImage && !_isUploading)
              TextButton.icon(
                icon: const Icon(AppIcons.close, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.rose500,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _removeImage,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),

        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: InkWell(
              onTap: _isUploading ? null : _pickImage,
              borderRadius: AppRadius.borderMd,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.lightSurfaceContainer,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutlineVariant,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image display
                    if (_localFile != null)
                      Image.file(
                        _localFile!,
                        fit: BoxFit.cover,
                      )
                    else if (_remoteUrl != null && _remoteUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: _remoteUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, _) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          ),
                        ),
                        errorWidget: (context, _, __) => const Icon(
                          AppIcons.image,
                          size: 32,
                          color: AppColors.slate400,
                        ),
                      )
                    else
                      // Empty state
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            AppIcons.image,
                            size: 36,
                            color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Tap to select cover image',
                            style: AppTypography.labelMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'JPEG, PNG, WebP up to 15MB',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary.withValues(alpha: 0.7)
                                  : AppColors.lightTextSecondary.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                    // Uploading overlay
                    if (_isUploading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Optimizing & uploading...',
                                style: AppTypography.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Error overlay
                    if (_errorMessage != null)
                      Container(
                        color: AppColors.rose500.withValues(alpha: 0.75),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 28),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                _errorMessage!,
                                style: AppTypography.labelSmall.copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Change Photo floating chip
                    if (hasImage && !_isUploading)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: AppRadius.borderPill,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
