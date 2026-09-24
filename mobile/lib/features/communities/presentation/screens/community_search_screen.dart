import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../application/community_search_controller.dart';
import '../widgets/community_card.dart';

/// Screen providing real-time search across all communities.
class CommunitySearchScreen extends ConsumerStatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  ConsumerState<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends ConsumerState<CommunitySearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final state = ref.watch(communitySearchControllerProvider);
    final controller = ref.read(communitySearchControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search communities, societies, clubs...',
              border: InputBorder.none,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(AppIcons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        controller.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            onChanged: (val) {
              setState(() {});
              controller.search(val);
            },
            onSubmitted: (val) => controller.search(val),
          ),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.isEmpty) {
            return Center(
              child: AppEmptyState(
                icon: AppIcons.search,
                title: 'No communities found',
                description:
                    'We couldn\'t find any communities matching "${state.query}". Try searching with different keywords.',
              ),
            );
          }

          if (state.results.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.communities,
                    size: 48,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  AppSpacing.gapVMd,
                  Text(
                    'Search for your society, neighborhood, or hobbies',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.results.length,
            separatorBuilder: (_, __) => AppSpacing.gapVMd,
            itemBuilder: (context, index) {
              final community = state.results[index];
              return CommunityCard(
                community: community,
                onTap: () => context.push('/communities/${community.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
