import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_empty_state.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_skeleton.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../../nearby/application/location_controller.dart';
import '../../../nearby/application/nearby_controller.dart';
import '../../../nearby/domain/entities/location_state.dart';
import '../../../nearby/presentation/widgets/locality_picker_dialog.dart';
import '../../../nearby/presentation/widgets/location_header_badge.dart';
import '../../../nearby/presentation/widgets/nearby_permission_view.dart';
import '../../../nearby/presentation/widgets/radius_selector.dart';

/// Production-grade Nearby Discovery screen for Aaspaas.
class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      final locState = ref.read(locationControllerProvider);
      if (locState is LocationReady) {
        ref.read(nearbyControllerProvider.notifier).loadMore(
              latitude: locState.latitude,
              longitude: locState.longitude,
            );
      } else if (locState is LocationManualLocality) {
        ref.read(nearbyControllerProvider.notifier).loadMore(
              latitude: locState.latitude,
              longitude: locState.longitude,
            );
      }
    }
  }

  Future<void> _openLocalityPicker() async {
    final result = await LocalityPickerDialog.show(context);
    if (result != null) {
      ref.read(locationControllerProvider.notifier).setManualLocality(
            localityName: result.locality,
            cityName: result.city,
            latitude: result.lat,
            longitude: result.lng,
          );
      await ref.read(nearbyControllerProvider.notifier).loadNearbyPosts(
            latitude: result.lat,
            longitude: result.lng,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locationState = ref.watch(locationControllerProvider);
    final nearbyState = ref.watch(nearbyControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUserId = authState is AuthAuthenticated
        ? authState.user.id
        : (authState is AuthOnboardingRequired ? authState.user.id : null);

    // Listen for transitions to LocationReady to trigger automatic initial load
    ref.listen<LocationState>(locationControllerProvider, (prev, next) {
      if (next is LocationReady && prev is! LocationReady) {
        ref.read(nearbyControllerProvider.notifier).loadNearbyPosts(
              latitude: next.latitude,
              longitude: next.longitude,
            );
      }
    });

    final hasLocation = locationState is LocationReady ||
        locationState is LocationManualLocality;

    double? activeLat;
    double? activeLng;
    if (locationState is LocationReady) {
      activeLat = locationState.latitude;
      activeLng = locationState.longitude;
    } else if (locationState is LocationManualLocality) {
      activeLat = locationState.latitude;
      activeLng = locationState.longitude;
    }

    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearby Discovery',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        actions: [
          if (hasLocation)
            IconButton(
              icon: const Icon(Icons.my_location_rounded, size: 22),
              tooltip: 'Use current location',
              onPressed: () {
                ref.read(locationControllerProvider.notifier).requestLocation();
              },
            ),
        ],
      ),
      body: ResponsiveContainer(
        child: !hasLocation
            ? NearbyPermissionView(
                locationState: locationState,
                onRequestLocation: () {
                  ref
                      .read(locationControllerProvider.notifier)
                      .requestLocation();
                },
                onChooseLocality: _openLocalityPicker,
                onOpenSettings: () {
                  ref
                      .read(locationControllerProvider.notifier)
                      .openAppSettings();
                },
                onOpenLocationSettings: () {
                  ref
                      .read(locationControllerProvider.notifier)
                      .openLocationSettings();
                },
              )
            : RefreshIndicator(
                color: primaryColor,
                onRefresh: () async {
                  if (activeLat != null && activeLng != null) {
                    await ref
                        .read(nearbyControllerProvider.notifier)
                        .loadNearbyPosts(
                          latitude: activeLat,
                          longitude: activeLng,
                          refresh: true,
                        );
                  }
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Location Header ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: LocationHeaderBadge(
                        locationState: locationState,
                        onChangeLocality: _openLocalityPicker,
                      ),
                    ),

                    // ── Radius Selector ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: RadiusSelector(
                        selectedRadiusKm: nearbyState.radiusKm,
                        onRadiusSelected: (radius) {
                          if (activeLat != null && activeLng != null) {
                            ref
                                .read(nearbyControllerProvider.notifier)
                                .setRadius(
                                  radius,
                                  latitude: activeLat,
                                  longitude: activeLng,
                                );
                          }
                        },
                      ),
                    ),

                    // ── Category Filters ────────────────────────────────────
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: FilterChip(
                                label: const Text('All Posts'),
                                selected: nearbyState.selectedCategory == null,
                                onSelected: (_) {
                                  if (activeLat != null && activeLng != null) {
                                    ref
                                        .read(nearbyControllerProvider.notifier)
                                        .setCategory(
                                          null,
                                          latitude: activeLat,
                                          longitude: activeLng,
                                        );
                                  }
                                },
                              ),
                            ),
                            ...PostCategory.values.map((cat) {
                              final isSelected =
                                  nearbyState.selectedCategory == cat;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: FilterChip(
                                  avatar: Icon(cat.icon, size: 16),
                                  label: Text(cat.label),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    if (activeLat != null &&
                                        activeLng != null) {
                                      ref
                                          .read(
                                            nearbyControllerProvider.notifier,
                                          )
                                          .setCategory(
                                            cat,
                                            latitude: activeLat,
                                            longitude: activeLng,
                                          );
                                    }
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),

                    // ── State Handling: Loading, Error, Empty, or Posts ────
                    if (nearbyState.isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => const Padding(
                              padding: EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppSkeleton(
                                height: 160,
                                borderRadius: AppRadius.card,
                              ),
                            ),
                            childCount: 4,
                          ),
                        ),
                      )
                    else if (nearbyState.errorMessage != null &&
                        nearbyState.posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppErrorState(
                          message: nearbyState.errorMessage!,
                          onRetry: () {
                            if (activeLat != null && activeLng != null) {
                              ref
                                  .read(nearbyControllerProvider.notifier)
                                  .loadNearbyPosts(
                                    latitude: activeLat,
                                    longitude: activeLng,
                                  );
                            }
                          },
                        ),
                      )
                    else if (nearbyState.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: AppEmptyState(
                            icon: AppIcons.nearby,
                            title: 'No posts within ${nearbyState.radiusKm} km',
                            description:
                                'There are no active posts around this area yet. Try increasing the search radius or exploring another locality.',
                            actionText: nearbyState.radiusKm < 20
                                ? 'Expand Radius to ${nearbyState.radiusKm == 5 ? 10 : 20} km'
                                : 'Choose Another Locality',
                            onAction: () {
                              if (nearbyState.radiusKm < 20 &&
                                  activeLat != null &&
                                  activeLng != null) {
                                final nextRadius =
                                    nearbyState.radiusKm == 5 ? 10 : 20;
                                ref
                                    .read(nearbyControllerProvider.notifier)
                                    .setRadius(
                                      nextRadius,
                                      latitude: activeLat,
                                      longitude: activeLng,
                                    );
                              } else {
                                _openLocalityPicker();
                              }
                            },
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = nearbyState.posts[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: PostCard(
                                  post: post,
                                  currentUserId: currentUserId,
                                  onTap: () {
                                    context.push('/feed/posts/${post.id}');
                                  },
                                  onLikePressed: () {
                                    ref
                                        .read(nearbyControllerProvider.notifier)
                                        .toggleLike(post.id);
                                  },
                                  onCommentPressed: () {
                                    context.push('/feed/posts/${post.id}');
                                  },
                                ),
                              );
                            },
                            childCount: nearbyState.posts.length,
                          ),
                        ),
                      ),

                    // ── Loading More Indicator ─────────────────────────────
                    if (nearbyState.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxl),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
