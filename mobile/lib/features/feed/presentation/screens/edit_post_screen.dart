import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../application/feed_controller.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/entities/post_entity.dart';

/// Screen allowing the author of a post to edit its content or category.
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
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _selectedCategory = widget.post.category;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(feedRepositoryProvider);
      final updatedPost = await repository.updatePost(
        postId: widget.post.id,
        content: content,
        category: _selectedCategory,
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
                return AppButton(
                  text: 'Save',
                  isFullWidth: false,
                  isLoading: _isSubmitting,
                  onPressed: hasContent ? _updatePost : null,
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
          ],
        ),
      ),
    );
  }
}
