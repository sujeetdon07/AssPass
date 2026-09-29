import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/app_media_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../l10n/messaging_localizations.dart';

class MessageComposer extends ConsumerStatefulWidget {
  const MessageComposer({
    required this.onSend,
    this.onSendImage,
    this.onTyping,
    super.key,
  });

  final ValueChanged<String> onSend;
  final void Function(File imageFile, String? caption)? onSendImage;
  final ValueChanged<String>? onTyping;

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  File? _selectedImage;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final text = _controller.text.trim();
    final canSendNow = text.isNotEmpty || _selectedImage != null;
    if (canSendNow != _canSend) {
      setState(() => _canSend = canSendNow);
    }
    widget.onTyping?.call(text);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (_selectedImage != null) {
      final image = _selectedImage!;
      setState(() {
        _selectedImage = null;
        _canSend = false;
      });
      widget.onSendImage?.call(image, text.isNotEmpty ? text : null);
      _controller.clear();
      return;
    }

    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _canSend = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop();
    final mediaService = ref.read(appMediaServiceProvider);
    final file = await mediaService.pickSingleImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
        _canSend = true;
      });
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.indigo500,
                  ),
                  title: Text(MessagingStrings.of(context, 'camera')),
                  subtitle: const Text('Take a photo (auto-compressed)'),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.indigo500,
                  ),
                  title: Text(MessagingStrings.of(context, 'gallery')),
                  subtitle: const Text('Choose from photos (auto-optimized)'),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? AppSpacing.sm
            : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkOutlineVariant
                : AppColors.lightOutlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected Image Attachment preview banner
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.lightSurfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                MessagingStrings.of(context, 'photo'),
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald500
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.bolt_rounded,
                                        size: 11,
                                        color: AppColors.emerald500,
                                      ),
                                    Text(
                                      MessagingStrings.of(context, 'optimized'),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.emerald500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Optimized WebP with instant thumbnail preview',
                            style: AppTypography.labelSmall.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _selectedImage = null;
                          _canSend = _controller.text.trim().isNotEmpty;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Input Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2, right: AppSpacing.xs),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                    ),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    tooltip: MessagingStrings.of(context, 'attachImage'),
                    onPressed: _showImageSourcePicker,
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainerHigh
                          : AppColors.lightSurfaceContainer,
                      borderRadius: AppRadius.chip,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      buildCounter: (
                        _, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) =>
                          null,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: _selectedImage != null
                            ? 'Add a caption (optional)...'
                            : MessagingStrings.of(context, 'typeMessage'),
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _canSend
                        ? (isDark ? AppColors.indigo500 : AppColors.indigo600)
                        : (isDark
                            ? AppColors.darkSurfaceContainerHigh
                            : AppColors.lightSurfaceContainer),
                    foregroundColor: _canSend
                        ? AppColors.pureWhite
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                  onPressed: _canSend ? _submit : null,
                  tooltip: MessagingStrings.of(context, 'send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
