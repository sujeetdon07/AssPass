import 'package:flutter/material.dart';
import 'package:aaspaas/core/theme/app_colors.dart';
import 'package:aaspaas/core/theme/app_radius.dart';
import 'package:aaspaas/core/theme/app_spacing.dart';
import 'package:aaspaas/core/theme/app_typography.dart';
import 'package:aaspaas/features/auth/data/repositories/auth_repository.dart';
import 'package:aaspaas/shared/widgets/avatars/app_avatar.dart';
import 'mention_autocomplete_controller.dart';

/// A polished Claymorphism mention suggestion panel that appears near the text composer.
class MentionSuggestionPanel extends StatelessWidget {
  const MentionSuggestionPanel({
    required this.controller,
    required this.onSelect,
    super.key,
  });

  final MentionAutocompleteController controller;
  final ValueChanged<UserSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.state == MentionState.hidden) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.lightSurface,
            borderRadius: AppRadius.borderLg,
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.lightOutlineVariant,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderLg,
            child: _buildContent(context, isDark),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (controller.state == MentionState.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
              ),
            ),
            AppSpacing.gapHSm,
            Text(
              'Searching neighbors...',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.state == MentionState.empty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 16,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            AppSpacing.gapHSm,
            Text(
              'No neighbors found with that handle',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.state == MentionState.error) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(
          'Unable to search mentions. Try again.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.rose600,
          ),
        ),
      );
    }

    final suggestions = controller.suggestions;
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: isDark
            ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
            : AppColors.lightOutlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final user = suggestions[index];
        final handle = '@${user.username ?? ''}';

        return Semantics(
          label: 'Mention ${user.displayName}, $handle',
          button: true,
          child: InkWell(
            onTap: () => onSelect(user),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user.avatarUrl,
                    name: user.displayName,
                    size: AppAvatarSize.s32,
                  ),
                  AppSpacing.gapHSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          handle,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
