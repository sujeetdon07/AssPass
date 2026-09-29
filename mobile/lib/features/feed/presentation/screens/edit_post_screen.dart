import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/app_media_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/media/app_multi_image_picker.dart';
import '../../application/feed_controller.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/entities/post_entity.dart';

/// Screen allowing the author of a post to edit its content, category, and images.
class EditPostScreen extends ConsumerStatefulWidget {
  const EditPostScreen({
    required this.post,
    super.key,
  });

  final PostEntity post;

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  late final TextEditingController _contentController;
  late PostCategory _selectedCategory;
  late final List<MediaUploadResult> _uploadedImages;
  bool _hasPendingUploads = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _selectedCategory = widget.post.category;
    _uploadedImages = widget.post.images
        .map((img) => MediaUploadResult(
              url: img.url,
              thumbnailUrl: img.thumbnailUrl ?? img.url,
              mediumUrl: img.mediumUrl,
              width: img.width ?? 0,
              height: img.height ?? 0,
              size: img.size ?? 0,
              mimeType: img.mimeType ?? 'image/webp',
            ),)
        .toList();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    if (_hasPendingUploads) {
      AppSnackbar.showWarning(
        context,
        message: 'Please wait for all image uploads to finish before saving.',
      );
      return;
    }

    if (_uploadedImages.length > 4) {
      AppSnackbar.showWarning(
        context,
        message: 'A post can have at most 4 images.',
      );
      return;
    }

    final imagePayload = _uploadedImages.asMap().entries.map((entry) {
      final idx = entry.key;
      final res = entry.value;
      return {
        'url': res.url,
        'thumbnailUrl': res.thumbnailUrl,
        if (res.mediumUrl != null) 'mediumUrl': res.mediumUrl,
        if (res.width > 0) 'width': res.width,
        if (res.height > 0) 'height': res.height,
        'mimeType': res.mimeType,
        if (res.size > 0) 'size': res.size,
        'sortOrder': idx,
      };
    }).toList();

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(feedRepositoryProvider);
      final updatedPost = await repository.updatePost(
        postId: widget.post.id,
        content: content,
        category: _selectedCategory,
        images: imagePayload,
      );

      ref.read(feedControllerProvider.notifier).updatePost(updatedPost);

      if (mounted) {
        context.pop(updatedPost);
        AppSnackbar.showSuccess(
          context,
          message: 'Post updated successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message: 'Unable to update post. Please try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, _) {
                final hasContent = value.text.trim().isNotEmpty;
                final canSave = hasContent && !_hasPendingUploads;
                return AppButton(
                  text: 'Save',
                  isFullWidth: false,
                  isLoading: _isSubmitting,
                  onPressed: canSave ? _updatePost : null,
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Selection
            Text(
              'Change Category',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.pureWhite : AppColors.slate900,
              ),
            ),
            AppSpacing.gapVSm,

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PostCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: AppChip(
                      label: cat.label,
                      icon: cat.icon,
                      isSelected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            AppSpacing.gapVLg,

            // Post Content Text Area
            AppTextField(
              controller: _contentController,
              hint: 'Update post content...',
              maxLines: 8,
              autofocus: true,
            ),

            AppSpacing.gapVLg,

            // Photos Attachment Section
            AppMultiImagePicker(
              label: 'Photos (max 4)',
              category: 'post',
              maxImages: 4,
              initialUrls: widget.post.images.map((i) => i.url).toList(),
              onMediaChanged: (mediaList) {
                setState(() {
                  _uploadedImages.clear();
                  _uploadedImages.addAll(mediaList);
                });
              },
              onUploadingChanged: (isUploading) {
                setState(() {
                  _hasPendingUploads = isUploading;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
