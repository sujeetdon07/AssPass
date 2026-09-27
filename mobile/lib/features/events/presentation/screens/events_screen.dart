import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/events_controller.dart';
import '../../domain/entities/event_category.dart';
import '../widgets/event_card.dart';
import '../widgets/event_filter_sheet.dart';

/// Main Events discovery and listing screen for Aaspaas.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
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
      ref.read(eventsControllerProvider.notifier).loadMore();
    }
  }

  void _openFilterSheet() {
    final state = ref.read(eventsControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => EventFilterSheet(
        selectedTimeframe: state.selectedTimeframe,
        selectedCategory: state.selectedCategory,
        onApply: (timeframe, category) {
          final controller = ref.read(eventsControllerProvider.notifier);
          controller.setTimeframe(timeframe);
          controller.setCategory(category);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsControllerProvider);
    final controller = ref.read(eventsControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: canPop
              ? null
              : BackButton(
                  onPressed: () => context.go(AppRoutes.home),
                ),
          title: const Text('Local Events'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.selectedCategory != null ||
                  state.selectedTimeframe != 'upcoming',
              child: const Icon(Icons.filter_list_outlined),
            ),
            tooltip: 'Filter events',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category quick-filter chip row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: state.selectedCategory == null,
                    onSelected: (_) => controller.setCategory(null),
                  ),
                ),
                ...EventCategory.values.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      avatar: Icon(cat.icon, size: 16),
                      label: Text(cat.label),
                      selected: state.selectedCategory == cat,
                      onSelected: (selected) {
                        controller.setCategory(selected ? cat : null);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main Event Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.loadEvents(isRefresh: true),
              child: Builder(
                builder: (context) {
                  if (state.isLoading && state.events.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.hasError && state.events.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy_outlined,
                              size: 56,
                              color: isDark ? AppColors.slate500 : AppColors.slate400,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              state.errorMessage ?? 'Failed to load events',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton.tonal(
                              onPressed: () => controller.loadEvents(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.indigo950 : AppColors.indigo50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month_outlined,
                                size: 48,
                                color: AppColors.indigo600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'No upcoming events found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Be the first to bring neighbors together by hosting an event!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.slate400 : AppColors.slate600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton.icon(
                              onPressed: () => context.push(AppRoutes.createEvent),
                              icon: const Icon(Icons.add),
                              label: const Text('Host an Event'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: state.events.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.events.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final event = state.events[index];
                      return EventCard(
                        event: event,
                        onTap: () {
                          context.push(
                            '/events/${event.id}',
                            extra: event,
                          );
                        },
                        onRsvpTap: (status) {
                          controller.rsvpEvent(event.id, status);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createEvent),
        icon: const Icon(Icons.add),
        label: const Text('Host Event'),
      ),
    ),
  );
  }
}
