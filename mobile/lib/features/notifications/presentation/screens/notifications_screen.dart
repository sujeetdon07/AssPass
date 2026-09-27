import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/notifications_controller.dart';
import '../../application/notifications_state.dart';
import '../../domain/models/notification_item.dart';
import '../../l10n/notifications_localizations.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(notificationsControllerProvider.notifier)
          .loadMoreNotifications();
    }
  }

  void _handleNotificationTap(NotificationItem item) {
    // Mark as read
    if (!item.isRead) {
      ref.read(notificationsControllerProvider.notifier).markAsRead(item.id);
    }

    // Handle Deep Link
    if (item.deepLink != null && item.deepLink!.isNotEmpty) {
      try {
        context.push(item.deepLink!);
      } catch (e) {
        debugPrint('[NotificationsScreen] Error navigating to deepLink: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    final unreadCount = state.items.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          NotificationsStrings.of(context, 'notifications'),
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            AppIconButton(
              icon: AppIcons.checkCircle,
              semanticLabel: NotificationsStrings.of(context, 'markAllAsRead'),
              iconSize: 22,
              onPressed: () {
                controller.markAllAsRead();
                AppSnackbar.showSuccess(
                  context,
                  message: NotificationsStrings.of(context, 'markAllAsRead'),
                );
              },
            ),
          AppIconButton(
            icon: AppIcons.settings,
            semanticLabel:
                NotificationsStrings.of(context, 'notificationSettings'),
            iconSize: 22,
            onPressed: () {
              context.push(AppRoutes.notificationSettings);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          _buildFilterChips(context, state.selectedFilter, controller, isDark),

          // Notification List
          Expanded(
            child: _buildBody(context, state, controller, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    NotificationFilter currentFilter,
    NotificationsController controller,
    bool isDark,
  ) {
    final filters = [
      (NotificationFilter.all, NotificationsStrings.of(context, 'all')),
      (NotificationFilter.unread, NotificationsStrings.of(context, 'unread')),
      (
        NotificationFilter.messages,
        NotificationsStrings.of(context, 'messages')
      ),
      (NotificationFilter.social, NotificationsStrings.of(context, 'social')),
      (
        NotificationFilter.community,
        NotificationsStrings.of(context, 'community')
      ),
      (
        NotificationFilter.marketplace,
        NotificationsStrings.of(context, 'marketplace')
      ),
      (
        NotificationFilter.business,
        NotificationsStrings.of(context, 'business')
      ),
      (NotificationFilter.system, NotificationsStrings.of(context, 'system')),
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate900 : AppColors.pureWhite,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.slate800 : AppColors.slate100,
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];
          final isSelected = currentFilter == filter;

          return FilterChip(
            label: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.pureWhite
                    : (isDark ? AppColors.slate300 : AppColors.slate700),
              ),
            ),
            selected: isSelected,
            onSelected: (_) => controller.setFilter(filter),
            backgroundColor: isDark ? AppColors.slate800 : AppColors.slate100,
            selectedColor: AppColors.indigo600,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? AppColors.indigo600
                    : (isDark ? AppColors.slate700 : AppColors.slate200),
                width: 0.8,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificationsState state,
    NotificationsController controller,
    bool isDark,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.indigo600),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.error,
                color: AppColors.rose500,
                size: 44,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                NotificationsStrings.of(context, 'errorLoading'),
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: NotificationsStrings.of(context, 'retry'),
                variant: AppButtonVariant.primary,
                isFullWidth: false,
                onPressed: () =>
                    controller.loadInitialNotifications(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => controller.loadInitialNotifications(refresh: true),
        color: AppColors.indigo600,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color:
                              (isDark ? AppColors.slate800 : AppColors.indigo50)
                                  .withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.notificationsOutline,
                          color:
                              isDark ? AppColors.slate400 : AppColors.indigo500,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        NotificationsStrings.of(context, 'noNotifications'),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        NotificationsStrings.of(
                          context,
                          'noNotificationsSubtitle',
                        ),
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              isDark ? AppColors.slate400 : AppColors.slate500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadInitialNotifications(refresh: true),
      color: AppColors.indigo600,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.indigo600,
                  ),
                ),
              ),
            );
          }

          final item = state.items[index];
          return NotificationTile(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _handleNotificationTap(item),
            onDelete: () {
              controller.deleteNotification(item.id);
              AppSnackbar.showSuccess(
                context,
                message:
                    NotificationsStrings.of(context, 'notificationDeleted'),
              );
            },
          );
        },
      ),
    );
  }
}
