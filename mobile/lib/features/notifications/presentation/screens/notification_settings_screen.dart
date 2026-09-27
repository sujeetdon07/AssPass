import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/notification_preferences_controller.dart';
import '../../l10n/notifications_localizations.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final prefsAsync = ref.watch(notificationPreferencesControllerProvider);
    final controller =
        ref.read(notificationPreferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          NotificationsStrings.of(context, 'notificationSettings'),
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: prefsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.indigo600),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.error, color: AppColors.rose500, size: 40),
                const SizedBox(height: AppSpacing.md),
                Text(
                  NotificationsStrings.of(context, 'errorLoading'),
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => controller.loadPreferences(),
                  child: Text(NotificationsStrings.of(context, 'retry')),
                ),
              ],
            ),
          ),
        ),
        data: (prefs) {
          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            children: [
              // Master Push Switch
              Material(
                color: isDark ? AppColors.slate900 : AppColors.pureWhite,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    NotificationsStrings.of(context, 'pushNotifications'),
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    NotificationsStrings.of(
                      context,
                      'pushNotificationsSubtitle',
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.slate400 : AppColors.slate500,
                    ),
                  ),
                  value: prefs.pushEnabled,
                  activeTrackColor: AppColors.indigo600,
                  activeThumbColor: AppColors.pureWhite,
                  onChanged: (val) {
                    controller.togglePush(val);
                    AppSnackbar.showSuccess(
                      context,
                      message:
                          NotificationsStrings.of(context, 'preferencesSaved'),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Privacy Note Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo950.withValues(alpha: 0.4)
                      : AppColors.indigo50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.indigo800 : AppColors.indigo100,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      AppIcons.privacy,
                      color: AppColors.indigo600,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        NotificationsStrings.of(context, 'privacyNote'),
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.indigo200
                              : AppColors.indigo900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Categories Header
              Text(
                NotificationsStrings.of(context, 'categories'),
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.slate300 : AppColors.slate700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Category Switches
              Material(
                color: isDark ? AppColors.slate900 : AppColors.pureWhite,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark ? AppColors.slate800 : AppColors.slate200,
                  ),
                ),
                child: Column(
                  children: [
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'messagesCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'messagesCategorySubtitle',
                      ),
                      icon: AppIcons.chat,
                      iconColor: AppColors.indigo600,
                      value: prefs.messagesEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('messages', val),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'socialCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'socialCategorySubtitle',
                      ),
                      icon: AppIcons.like,
                      iconColor: AppColors.rose500,
                      value: prefs.socialEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('social', val),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'communityCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'communityCategorySubtitle',
                      ),
                      icon: AppIcons.communities,
                      iconColor: AppColors.teal600,
                      value: prefs.communityEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('community', val),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'marketplaceCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'marketplaceCategorySubtitle',
                      ),
                      icon: AppIcons.marketplace,
                      iconColor: AppColors.amber500,
                      value: prefs.marketplaceEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('marketplace', val),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'businessCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'businessCategorySubtitle',
                      ),
                      icon: AppIcons.business,
                      iconColor: AppColors.violet600,
                      value: prefs.businessEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('business', val),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildCategoryTile(
                      context,
                      title: NotificationsStrings.of(
                        context,
                        'systemCategoryTitle',
                      ),
                      subtitle: NotificationsStrings.of(
                        context,
                        'systemCategorySubtitle',
                      ),
                      icon: AppIcons.info,
                      iconColor: AppColors.slate600,
                      value: prefs.systemEnabled,
                      enabled: prefs.pushEnabled,
                      onChanged: (val) =>
                          controller.updateCategory('system', val),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: enabled ? 0.12 : 0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled ? iconColor : AppColors.slate400,
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: enabled
              ? (isDark ? AppColors.slate100 : AppColors.slate900)
              : AppColors.slate400,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(
          color: enabled
              ? (isDark ? AppColors.slate400 : AppColors.slate500)
              : AppColors.slate400,
          fontSize: 12,
        ),
      ),
      value: value,
      activeTrackColor: AppColors.indigo600,
      activeThumbColor: AppColors.pureWhite,
      onChanged: enabled ? onChanged : null,
    );
  }
}
