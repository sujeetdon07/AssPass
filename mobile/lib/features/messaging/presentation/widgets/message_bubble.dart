import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/media/app_cached_image.dart';
import '../../domain/entities/message_entity.dart';
import 'chat_photo_viewer.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.onRetry,
    this.onLongPress,
    super.key,
  });

  final MessageEntity message;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMe = message.isMe;

    final bubbleBg = isMe
        ? (isDark ? AppColors.indigo700 : AppColors.indigo600)
        : (isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.lightSurfaceContainer);

    final textColor = isMe
        ? AppColors.pureWhite
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    final timeColor = isMe
        ? AppColors.pureWhite.withValues(alpha: 0.7)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final isDeleted = message.content == 'This message was deleted';
    final isImage = message.isImage;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isMe && message.isFailed)
              GestureDetector(
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.xs, bottom: 4),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.rose500,
                    size: 20,
                  ),
                ),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: isDeleted ? null : onLongPress,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: isImage
                      ? const EdgeInsets.all(4)
                      : const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.md),
                      topRight: const Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(isMe ? AppRadius.md : 4),
                      bottomRight: Radius.circular(isMe ? 4 : AppRadius.md),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pureBlack.withValues(alpha: 0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isImage) _buildImageContent(context),
                      if (!isImage)
                        Text(
                          message.content,
                          style: AppTypography.bodyMedium.copyWith(
                            color: textColor,
                            fontStyle:
                                isDeleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      if (isImage && message.hasCaption)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.sm,
                            right: AppSpacing.sm,
                            top: AppSpacing.xs,
                            bottom: 2,
                          ),
                          child: Text(
                            message.content,
                            style: AppTypography.bodyMedium.copyWith(
                              color: textColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: isImage
                            ? const EdgeInsets.only(right: 6, bottom: 4, top: 2)
                            : EdgeInsets.zero,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: AppTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: timeColor,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusIcon(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final double aspectRatio = (message.mediaWidth != null &&
            message.mediaHeight != null &&
            message.mediaHeight! > 0)
        ? (message.mediaWidth! / message.mediaHeight!).clamp(0.6, 1.8)
        : 1.2;

    final hasLocal = message.localImagePath != null &&
        message.localImagePath!.isNotEmpty &&
        File(message.localImagePath!).existsSync();

    return GestureDetector(
      onTap: () {
        if (!message.isFailed) {
          ChatPhotoViewer.show(
            context,
            imageUrl: message.mediaUrl ?? '',
            thumbnailUrl: message.mediaThumbnailUrl,
            localImagePath: message.localImagePath,
            caption: message.content,
            heroTag: 'msg_${message.clientMessageId}',
          );
        } else {
          onRetry?.call();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 2),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasLocal)
                Image.file(
                  File(message.localImagePath!),
                  fit: BoxFit.cover,
                )
              else
                AppCachedImage(
                  imageUrl: message.mediaUrl ?? '',
                  thumbnailUrl: message.mediaThumbnailUrl,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.zero,
                ),

              // Sending overlay
              if (message.isSending)
                Container(
                  color: AppColors.pureBlack.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.pureWhite),
                      ),
                    ),
                  ),
                ),

              // Failed overlay
              if (message.isFailed)
                Container(
                  color: AppColors.pureBlack.withValues(alpha: 0.45),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: AppColors.pureWhite,
                          size: 30,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap to retry',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 11,
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
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.pureWhite),
          ),
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 12,
          color: AppColors.rose500,
        );
      case MessageStatus.sent:
        if (message.isRead) {
          return const Icon(
            Icons.done_all_rounded,
            size: 14,
            color: AppColors.emerald500,
          );
        }
        return const Icon(
          Icons.done_rounded,
          size: 14,
          color: AppColors.pureWhite,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
