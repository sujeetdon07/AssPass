import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../application/community_members_controller.dart';

/// Screen displaying paginated list of members for a community.
class CommunityMembersScreen extends ConsumerStatefulWidget {
  const CommunityMembersScreen({
    required this.communityId,
    super.key,
  });

  final String communityId;

  @override
  ConsumerState<CommunityMembersScreen> createState() =>
      _CommunityMembersScreenState();
}

class _CommunityMembersScreenState
    extends ConsumerState<CommunityMembersScreen> {
  final _scrollController = ScrollController();

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
          .read(communityMembersControllerProvider(widget.communityId).notifier)
          .loadMore();
    }
  }

  Widget _buildRoleBadge(String role, bool isDark) {
    final isOwner = role.toLowerCase() == 'owner';
    final isMod = role.toLowerCase() == 'moderator';

    if (!isOwner && !isMod) return const SizedBox.shrink();

    final bgColor = isOwner
        ? (isDark
            ? AppColors.indigo900.withValues(alpha: 0.4)
            : AppColors.indigo50)
        : (isDark
            ? AppColors.violet900.withValues(alpha: 0.4)
            : AppColors.violet50);

    final fgColor = isOwner
        ? (isDark ? AppColors.indigo300 : AppColors.indigo700)
        : (isDark ? AppColors.violet300 : AppColors.violet700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        role.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: fgColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state =
        ref.watch(communityMembersControllerProvider(widget.communityId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Members'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(
              communityMembersControllerProvider(widget.communityId).notifier,
            )
            .loadMembers(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.isEmpty
                ? const Center(
                    child: AppEmptyState(
                      icon: AppIcons.communities,
                      title: 'No members found',
                      description: 'No members are currently listed.',
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount:
                        state.members.length + (state.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.darkOutlineVariant.withValues(alpha: 0.4)
                          : AppColors.lightOutlineVariant
                              .withValues(alpha: 0.4),
                    ),
                    itemBuilder: (context, index) {
                      if (index == state.members.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final member = state.members[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            AppAvatar(
                              name: member.displayName,
                              imageUrl: member.avatarUrl,
                              size: AppAvatarSize.s40,
                            ),
                            AppSpacing.gapHMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          member.displayName,
                                          style:
                                              AppTypography.titleSmall.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildRoleBadge(member.role, isDark),
                                    ],
                                  ),
                                  if (member.locationSummary.isNotEmpty) ...[
                                    AppSpacing.gapHXxs,
                                    Row(
                                      children: [
                                        Icon(
                                          AppIcons.location,
                                          size: 12,
                                          color: isDark
                                              ? AppColors.darkTextTertiary
                                              : AppColors.lightTextTertiary,
                                        ),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: Text(
                                            member.locationSummary,
                                            style: AppTypography.labelSmall
                                                .copyWith(
                                              color: isDark
                                                  ? AppColors.darkTextTertiary
                                                  : AppColors.lightTextTertiary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
