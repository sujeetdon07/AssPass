import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/chips/app_chip.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../communities/application/community_detail_controller.dart';
import '../../../communities/data/repositories/communities_repository.dart';
import '../../application/feed_controller.dart';
import '../../data/repositories/feed_repository.dart';
import '../../domain/entities/post_entity.dart';
import '../../../../core/services/app_media_service.dart';
import '../../../../shared/widgets/media/app_multi_image_picker.dart';
import '../widgets/mentions/mention_autocomplete_controller.dart';
import '../widgets/mentions/mention_suggestion_panel.dart';

/// Screen allowing authenticated users to create a new post in their community feed or a specific group.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    this.communityId,
    this.communityName,
    super.key,
  });

  final String? communityId;
  final String? communityName;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  late final MentionAutocompleteController _mentionController;
  final List<MediaUploadResult> _uploadedImages = [];
  bool _hasPendingUploads = false;
  PostCategory _selectedCategory = PostCategory.general;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _mentionController = MentionAutocompleteController(
      searchUsers: (query) => ref.read(authRepositoryProvider).searchUsers(query),
    );
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    _mentionController.onTextChanged(
      text: _contentController.text,
      selection: _contentController.selection,
    );
  }

  void _onSelectMention(UserSearchResult user) {
    final updatedValue = _mentionController.applyMention(
      user: user,
      currentValue: _contentController.value,
    );
    _contentController.value = updatedValue;
    _contentFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    _contentFocusNode.dispose();
    _mentionController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    if (_hasPendingUploads) {
      AppSnackbar.showWarning(
        context,
        message: 'Please wait for all image uploads to finish before posting.',
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

    final mentions = _mentionController.getStructuredMentions(content);

    // Build image payloads preserving ordering
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
      if (widget.communityId != null) {
        final communitiesRepo = ref.read(communitiesRepositoryProvider);
        final newPost = await communitiesRepo.createCommunityPost(
          id: widget.communityId!,
          content: content,
          category: _selectedCategory,
          mentions: mentions,
          images: imagePayload,
        );

        ref
            .read(
              communityDetailControllerProvider(widget.communityId!).notifier,
            )
            .loadPosts();
        ref.read(feedControllerProvider.notifier).addPost(newPost);
      } else {
        final repository = ref.read(feedRepositoryProvider);
        final newPost = await repository.createPost(
          content: content,
          category: _selectedCategory,
          mentions: mentions,
          images: imagePayload,
        );

        ref.read(feedControllerProvider.notifier).addPost(newPost);
      }

      if (mounted) {
        context.pop();
        AppSnackbar.showSuccess(
          context,
          message: widget.communityName != null
              ? 'Post published to ${widget.communityName}.'
              : 'Post published to your local community feed.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message:
              'Unable to publish post. Please check your network and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authControllerProvider);
    final localityDisplay = authState is AuthAuthenticated
        ? authState.user.localitySummary
        : 'Your Locality';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.communityName != null
              ? 'Post in ${widget.communityName}'
              : 'Create Post',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _contentController,
              builder: (context, value, _) {
                final hasContent = value.text.trim().isNotEmpty;
                final canPost = hasContent && !_hasPendingUploads;
                return AppButton(
                  text: 'Post',
                  isFullWidth: false,
                  isLoading: _isSubmitting,
                  onPressed: canPost ? _submitPost : null,
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
            // Locality / Community Scoping Notice (Privacy Guaranteed)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
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
              child: Row(
                children: [
                  Icon(
                    widget.communityName != null
                        ? AppIcons.communities
                        : AppIcons.location,
                    size: 16,
                    color:
                        isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                  ),
                  AppSpacing.gapHSm,
                  Expanded(
                    child: Text(
                      widget.communityName != null
                          ? 'Posting to ${widget.communityName}'
                          : 'Sharing with neighbors in $localityDisplay',
                      style: AppTypography.labelMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.gapVMd,

            // Category Selection
            Text(
              'Select Category',
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

            // Mention Suggestions Panel
            MentionSuggestionPanel(
              controller: _mentionController,
              onSelect: _onSelectMention,
            ),

            // Post Content Text Area
            AppTextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              hint:
                  "What's happening in your neighborhood? Share updates, ask questions, or recommend local spots...",
              maxLines: 8,
              autofocus: true,
            ),

            AppSpacing.gapVLg,

            // Photos Attachment Section
            AppMultiImagePicker(
              label: 'Add Photos (optional)',
              category: 'post',
              maxImages: 4,
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
