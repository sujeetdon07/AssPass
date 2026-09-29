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
import '../feedback/app_snackbar.dart';

/// Represents a single image item in the multi-image picker.
class PickedImageItem {
  PickedImageItem({
    this.localFile,
    this.remoteUrl,
    this.thumbnailUrl,
    this.uploadResult,
    this.isUploading = false,
    this.uploadProgress,
    this.uploadError,
  });

  final File? localFile;
  String? remoteUrl;
  String? thumbnailUrl;
  MediaUploadResult? uploadResult;
  bool isUploading;
  double? uploadProgress;
  String? uploadError;

  bool get isUploaded => remoteUrl != null && remoteUrl!.isNotEmpty;
  String get displayUrl => thumbnailUrl ?? remoteUrl ?? '';
}

/// Claymorphic multi-image picker supporting Gallery selection, immediate local
/// preview, asynchronous server uploads, and deletion/retry.
class AppMultiImagePicker extends ConsumerStatefulWidget {
  const AppMultiImagePicker({
    this.initialUrls = const [],
    this.onUrlsChanged,
    this.onMediaChanged,
    this.onUploadingChanged,
    this.maxImages = 4,
    this.category = 'content',
    this.label = 'Photos',
    super.key,
  });

  /// Existing remote URLs (e.g. when editing a listing).
  final List<String> initialUrls;

  /// Invoked whenever the list of successfully uploaded/selected URLs changes.
  final ValueChanged<List<String>>? onUrlsChanged;

  /// Invoked with rich metadata for uploaded images.
  final ValueChanged<List<MediaUploadResult>>? onMediaChanged;

  /// Invoked when upload activity changes (true if any item is uploading or has error).
  final ValueChanged<bool>? onUploadingChanged;

  /// Maximum allowed photos.
  final int maxImages;

  /// Media category passed to backend (e.g. 'marketplace', 'post').
  final String category;

  /// Label shown above the picker.
  final String label;

  @override
  ConsumerState<AppMultiImagePicker> createState() => _AppMultiImagePickerState();
}

class _AppMultiImagePickerState extends ConsumerState<AppMultiImagePicker> {
  final List<PickedImageItem> _items = [];
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    for (final url in widget.initialUrls) {
      if (url.trim().isNotEmpty) {
        _items.add(PickedImageItem(
          remoteUrl: url,
          thumbnailUrl: url,
          uploadResult: MediaUploadResult(
            url: url,
            thumbnailUrl: url,
            width: 0,
            height: 0,
            size: 0,
            mimeType: 'image/webp',
          ),
        ),);
      }
    }
  }

  void _notifyParent() {
    final validUrls = _items
        .where((item) => item.remoteUrl != null && item.remoteUrl!.isNotEmpty)
        .map((item) => item.remoteUrl!)
        .toList();
    widget.onUrlsChanged?.call(validUrls);

    final results = _items
        .where((item) => item.uploadResult != null)
        .map((item) => item.uploadResult!)
        .toList();
    widget.onMediaChanged?.call(results);

    final hasPending = _items.any((item) => item.isUploading || item.uploadError != null);
    widget.onUploadingChanged?.call(hasPending);
  }

  Future<void> _pickImages() async {
    if (_isPicking) return;
    final remainingSlots = widget.maxImages - _items.length;
    if (remainingSlots <= 0) {
      AppSnackbar.showWarning(
        context,
        message: 'Maximum ${widget.maxImages} photos allowed.',
      );
      return;
    }

    setState(() => _isPicking = true);

    try {
      final mediaService = ref.read(appMediaServiceProvider);
      final files = await mediaService.pickMultipleImages(
        limit: remainingSlots,
      );

      if (files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      // Filter duplicates by path
      final newFiles = files.where((f) {
        return !_items.any((item) => item.localFile?.path == f.path);
      }).toList();

      if (newFiles.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final newItems = newFiles.map((file) {
        return PickedImageItem(localFile: file, isUploading: true);
      }).toList();

      setState(() {
        _items.addAll(newItems);
        _isPicking = false;
      });

      _notifyParent();

      // Upload each new file
      for (final item in newItems) {
        _uploadItem(item);
      }
    } catch (e) {
      debugPrint('[AppMultiImagePicker] Pick error: $e');
      setState(() => _isPicking = false);
    }
  }

  Future<void> _uploadItem(PickedImageItem item) async {
    if (item.localFile == null) return;

    setState(() {
      item.isUploading = true;
      item.uploadProgress = 0.0;
      item.uploadError = null;
    });
    _notifyParent();

    try {
      final mediaService = ref.read(appMediaServiceProvider);
      final result = await mediaService.uploadImage(
        item.localFile!,
        type: widget.category,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() {
              item.uploadProgress = sent / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          item.isUploading = false;
          item.uploadProgress = null;
          item.uploadResult = result;
          item.remoteUrl = result.url;
          item.thumbnailUrl = result.thumbnailUrl;
        });
        _notifyParent();
      }
    } catch (e) {
      debugPrint('[AppMultiImagePicker] Upload failed for ${item.localFile?.path}: $e');
      if (mounted) {
        setState(() {
          item.isUploading = false;
          item.uploadProgress = null;
          item.uploadError = 'Upload failed';
        });
        _notifyParent();
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _notifyParent();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            Text(
              '${_items.length}/${widget.maxImages}',
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Photos Row / Grid
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Add Photos Action Card
              if (_items.length < widget.maxImages)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: InkWell(
                    onTap: _isPicking ? null : _pickImages,
                    borderRadius: AppRadius.borderMd,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainerHigh
                            : AppColors.lightSurfaceContainer,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkOutlineVariant
                              : AppColors.lightOutlineVariant,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isPicking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  AppIcons.add,
                                  size: 26,
                                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                                ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Add Photo',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Preview items
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Thumbnail Card
                      ClipRRect(
                        borderRadius: AppRadius.borderMd,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainer
                                : AppColors.lightSurfaceContainerLow,
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: item.localFile != null
                              ? Image.file(
                                  item.localFile!,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.displayUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (context, _) => Container(
                                    color: isDark
                                        ? AppColors.darkSurfaceContainerHigh
                                        : AppColors.lightSurfaceContainer,
                                  ),
                                  errorWidget: (context, _, __) => const Icon(
                                    AppIcons.image,
                                    size: 24,
                                    color: AppColors.rose500,
                                  ),
                                ),
                        ),
                      ),

                      // Uploading progress overlay
                      if (item.isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: AppRadius.borderMd,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      value: (item.uploadProgress != null && item.uploadProgress! > 0)
                                          ? item.uploadProgress
                                          : null,
                                      strokeWidth: 2.5,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  if (item.uploadProgress != null && item.uploadProgress! > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(item.uploadProgress! * 100).toInt()}%',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Error retry overlay
                      if (item.uploadError != null)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.rose500.withValues(alpha: 0.8),
                              borderRadius: AppRadius.borderMd,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                                    tooltip: 'Retry upload',
                                    onPressed: () => _uploadItem(item),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Retry',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Remove button badge (top right)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _removeItem(index),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.slate900,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              AppIcons.close,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
