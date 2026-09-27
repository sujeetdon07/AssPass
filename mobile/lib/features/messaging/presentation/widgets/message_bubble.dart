import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/message_entity.dart';

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
                  padding: const EdgeInsets.symmetric(
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
                    children: [
                      Text(
                        message.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: textColor,
                          fontStyle:
                              isDeleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
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
