import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../communities/application/communities_controller.dart';
import '../../../communities/application/communities_state.dart';
import '../../../communities/presentation/widgets/community_card.dart';
import '../../../communities/presentation/widgets/community_category_chips.dart';
import '../../../communities/presentation/widgets/join_leave_dialogs.dart';

/// Full Communities tab screen in Aaspaas.
///
/// Features:
/// - Tab switching: All Communities, In My Area, My Communities
/// - Dynamic category filtering (Society/RWA, Interest, Parents, Pets, Civic, etc.)
/// - Real-time join/leave mutations with optimistic updates
/// - Direct search navigation and "Create Community" flow
/// - Infinite scroll pagination and pull-to-refresh
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final tab = CommunitiesTab.values[_tabController.index];
      ref.read(communitiesControllerProvider.notifier).setTab(tab);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(communitiesControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesControllerProvider);
    final controller = ref.read(communitiesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.search),
            tooltip: 'Search Communities',
            onPressed: () => context.push('/communities/search'),
          ),
          IconButton(
            icon: const Icon(AppIcons.add),
            tooltip: 'Create Community',
            onPressed: () => context.push('/communities/create'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'In My Area'),
            Tab(text: 'My Communities'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/communities/create'),
        icon: const Icon(AppIcons.add),
        label: const Text('New Community'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadCommunities(isRefresh: true),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Category Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: CommunityCategoryChips(
                  selectedCategory: state.selectedCategory,
                  onCategorySelected: (cat) => controller.setCategory(cat),
                ),
              ),
            ),

            // Loading state
            if (state.isLoading && state.communities.isEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppSkeleton(
                        width: double.infinity,
                        height: 140,
                      ),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
            ] else if (state.hasError && state.communities.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: AppErrorState(
                      title: 'Unable to load communities',
                      message: state.errorMessage ??
                          'Please check your connection and try again.',
                      onRetry: () => controller.loadCommunities(),
                    ),
                  ),
                ),
              ),
            ] else if (state.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: AppEmptyState(
                        icon: AppIcons.communities,
                        title: state.selectedTab == CommunitiesTab.joined
                            ? 'No joined communities yet'
                            : 'No communities found',
                        description: state.selectedTab == CommunitiesTab.joined
                            ? 'Discover and join apartment societies, local resident welfare associations, or neighborhood clubs!'
                            : 'Be the first neighbor to start a community in this category!',
                        actionText: state.selectedTab == CommunitiesTab.joined
                            ? 'Explore Communities'
                            : 'Create Community',
                        onAction: state.selectedTab == CommunitiesTab.joined
                            ? () => _tabController.animateTo(0)
                            : () => context.push('/communities/create'),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  80, // padding for FAB
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == state.communities.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final community = state.communities[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: CommunityCard(
                          community: community,
                          onTap: () =>
                              context.push('/communities/${community.id}'),
                          onJoinToggle: () async {
                            if (community.currentUserMember) {
                              if (community.isOwner) {
                                await showOwnerCannotLeaveDialog(context);
                                return;
                              }
                              final confirmed = await showLeaveCommunityDialog(
                                context,
                                communityName: community.name,
                                isPrivate: community.isPrivate,
                              );
                              if (confirmed == true) {
                                await controller.toggleJoin(community);
                              }
                            } else {
                              await controller.toggleJoin(community);
                            }
                          },
                        ),
                      );
                    },
                    childCount: state.communities.length +
                        (state.isLoadingMore ? 1 : 0),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
