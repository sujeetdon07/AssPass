import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/app_media_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../feedback/app_snackbar.dart';
import 'app_square_crop_dialog.dart';

/// Interactive circular avatar picker with Gallery selection, 1:1 square crop,
/// and backend upload.
class AppAvatarPicker extends ConsumerStatefulWidget {
  const AppAvatarPicker({
    this.currentAvatarUrl,
    required this.onAvatarUploaded,
    this.size = 96.0,
    super.key,
  });

  final String? currentAvatarUrl;
  final ValueChanged<String> onAvatarUploaded;
  final double size;

  @override
  ConsumerState<AppAvatarPicker> createState() => _AppAvatarPickerState();
}

class _AppAvatarPickerState extends ConsumerState<AppAvatarPicker> {
  File? _localCroppedFile;
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.currentAvatarUrl;
  }

  @override
  void didUpdateWidget(covariant AppAvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAvatarUrl != oldWidget.currentAvatarUrl) {
      _avatarUrl = widget.currentAvatarUrl;
    }
  }

  Future<void> _pickAndCropAvatar() async {
    final mediaService = ref.read(appMediaServiceProvider);

    // 1. Pick image from Android gallery
    final pickedFile = await mediaService.pickSingleImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );

    if (pickedFile == null || !mounted) return;

    // 2. Open interactive 1:1 square crop modal
    final croppedFile = await AppSquareCropDialog.show(context, pickedFile);
    if (croppedFile == null || !mounted) return;

    // 3. Immediately show local preview
    setState(() {
      _localCroppedFile = croppedFile;
      _isUploading = true;
    });

    // 4. Upload cropped square image to backend with type: 'avatar'
    try {
      final result = await mediaService.uploadImage(croppedFile, type: 'avatar');
      if (mounted) {
        setState(() {
          _isUploading = false;
          _avatarUrl = result.url;
        });
        widget.onAvatarUploaded(result.url);
        AppSnackbar.showSuccess(context, message: 'Profile picture updated.');
      }
    } catch (e) {
      debugPrint('[AppAvatarPicker] Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        AppSnackbar.showError(
          context,
          message: 'Failed to upload profile picture. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Avatar Container
          GestureDetector(
            onTap: _isUploading ? null : _pickAndCropAvatar,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkPrimaryContainer : const Color(0xFFE8EBFF),
                border: Border.all(
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: _buildAvatarContent(),
              ),
            ),
          ),

          // Uploading spinner
          if (_isUploading)
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),

          // Camera Badge on bottom right
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _pickAndCropAvatar,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    if (_localCroppedFile != null) {
      return Image.file(
        _localCroppedFile!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
      );
    }

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _avatarUrl!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        placeholder: (context, _) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, _, __) => const Icon(
          AppIcons.profile,
          size: 40,
          color: AppColors.slate400,
        ),
      );
    }

    return const Icon(
      AppIcons.profile,
      size: 44,
      color: AppColors.lightPrimary,
    );
  }
}
