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
  final List<String> _photoUrls = [];
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

    final effectiveContent = _photoUrls.isNotEmpty
        ? '$content\n\n${_photoUrls.join('\n')}'
        : content;

    final mentions = _mentionController.getStructuredMentions(effectiveContent);

    setState(() => _isSubmitting = true);

    try {
      if (widget.communityId != null) {
        final communitiesRepo = ref.read(communitiesRepositoryProvider);
        final newPost = await communitiesRepo.createCommunityPost(
          id: widget.communityId!,
          content: effectiveContent,
          category: _selectedCategory,
          mentions: mentions,
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
          content: effectiveContent,
          category: _selectedCategory,
          mentions: mentions,
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
                return AppButton(
                  text: 'Post',
                  isFullWidth: false,
                  isLoading: _isSubmitting,
                  onPressed: hasContent ? _submitPost : null,
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
              initialUrls: _photoUrls,
              onUrlsChanged: (urls) {
                setState(() {
                  _photoUrls.clear();
                  _photoUrls.addAll(urls);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
