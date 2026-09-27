import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../application/unread_notifications_counter.dart';

class NotificationBadge extends ConsumerWidget {
  const NotificationBadge({
    super.key,
    required this.onPressed,
    this.iconSize = 22.0,
    this.minTouchTarget = 48.0,
  });

  final VoidCallback onPressed;
  final double iconSize;
  final double minTouchTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: unreadCount > 0
              ? AppIcons.notifications
              : AppIcons.notificationsOutline,
          semanticLabel: 'Notifications',
          iconSize: iconSize,
          minTouchTarget: minTouchTarget,
          onPressed: onPressed,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.rose500,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
