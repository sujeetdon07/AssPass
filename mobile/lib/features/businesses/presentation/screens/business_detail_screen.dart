import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/avatars/app_avatar.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/businesses_controller.dart';
import '../../data/repositories/businesses_repository.dart';
import '../../domain/entities/business_entity.dart';
import '../../domain/entities/operating_hours.dart';
import '../widgets/report_business_dialog.dart';
import '../../../messaging/domain/repositories/messaging_repository.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  const BusinessDetailScreen({required this.businessId, super.key});

  final String businessId;

  @override
  ConsumerState<BusinessDetailScreen> createState() =>
      _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  BusinessEntity? _business;
  bool _isLoading = true;
  String? _errorMessage;
  int _activeImageIndex = 0;
  bool _isHoursExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(businessesRepositoryProvider);
      final model = await repo.getBusinessById(widget.businessId);
      if (mounted) {
        setState(() {
          _business = model;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load business details. Please retry.';
        });
      }
    }
  }

  Future<void> _handleFavoriteToggle() async {
    if (_business == null) return;
    final current = _business!;
    final targetFav = !current.isFavorited;
    final targetCount =
        targetFav ? current.favoriteCount + 1 : current.favoriteCount - 1;

    setState(() {
      _business = BusinessEntity(
        id: current.id,
        ownerId: current.ownerId,
        owner: current.owner,
        name: current.name,
        slug: current.slug,
        description: current.description,
        category: current.category,
        status: current.status,
        verificationStatus: current.verificationStatus,
        countryCode: current.countryCode,
        state: current.state,
        district: current.district,
        city: current.city,
        locality: current.locality,
        neighborhood: current.neighborhood,
        address: current.address,
        contactPhone: current.contactPhone,
        contactEmail: current.contactEmail,
        website: current.website,
        timezone: current.timezone,
        operatingHours: current.operatingHours,
        operatingStatus: current.operatingStatus,
        favoriteCount: targetCount < 0 ? 0 : targetCount,
        isFavorited: targetFav,
        isOwner: current.isOwner,
        images: current.images,
        services: current.services,
        distance: current.distance,
        distanceMeters: current.distanceMeters,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
    });

    // Also sync in controller
    ref.read(businessesControllerProvider.notifier).toggleFavorite(current.id);
  }

  Future<void> _openReportDialog() async {
    if (_business == null) return;
    final reported = await ReportBusinessDialog.show(
      context,
      businessId: _business!.id,
      businessName: _business!.name,
      onSubmit: (reason, details) async {
        final repo = ref.read(businessesRepositoryProvider);
        await repo.reportBusiness(_business!.id, reason, details);
      },
    );

    if (reported == true && mounted) {
      AppSnackbar.showSuccess(
        context,
        message:
            'Report submitted. Our moderation team will inspect this listing.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _business == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: AppErrorState(
            title: 'Business Not Found',
            message:
                _errorMessage ?? 'This business listing could not be found.',
            onRetry: _loadBusiness,
          ),
        ),
      );
    }

    final b = _business!;
    final status = b.operatingStatus;

    Color statusColor;
    Color statusBgColor;
    if (status.isOpen) {
      statusColor = isDark ? AppColors.darkSuccess : AppColors.lightSuccess;
      statusBgColor = isDark
          ? AppColors.darkSuccess.withValues(alpha: 0.15)
          : AppColors.lightSuccess.withValues(alpha: 0.12);
    } else {
      statusColor = isDark ? AppColors.darkTextSecondary : AppColors.slate500;
      statusBgColor = isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurfaceContainer;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          b.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              b.isFavorited ? AppIcons.like : AppIcons.likeOutline,
              color: b.isFavorited ? AppColors.rose500 : null,
            ),
            tooltip: b.isFavorited ? 'Remove Favorite' : 'Favorite',
            onPressed: _handleFavoriteToggle,
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            onSelected: (val) {
              if (val == 'report') {
                _openReportDialog();
              } else if (val == 'edit') {
                context.push('/businesses/${b.id}/edit', extra: b).then((_) {
                  _loadBusiness();
                });
              }
            },
            itemBuilder: (context) => [
              if (b.isOwner)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, size: 18),
                      AppSpacing.gapHSm,
                      Text('Edit Business'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(AppIcons.report, size: 18),
                    AppSpacing.gapHSm,
                    Text('Report Business'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Gallery ────────────────────────────────────────────────
            if (b.images.isNotEmpty) ...[
              SizedBox(
                height: 240,
                child: PageView.builder(
                  itemCount: b.images.length,
                  onPageChanged: (idx) =>
                      setState(() => _activeImageIndex = idx),
                  itemBuilder: (context, idx) {
                    final img = b.images[idx];
                    return Image.network(
                      img.url,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) =>
                          _buildPlaceholderHeader(isDark, b),
                    );
                  },
                ),
              ),
              if (b.images.length > 1) ...[
                AppSpacing.gapVSm,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    b.images.length,
                    (idx) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _activeImageIndex == idx
                            ? AppColors.indigo600
                            : (isDark
                                ? AppColors.slate700
                                : AppColors.slate300),
                      ),
                    ),
                  ),
                ),
              ],
            ] else
              _buildPlaceholderHeader(isDark, b),

            // ── Primary Details ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category & Open/Close badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainer,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(b.category.icon, size: 14),
                            AppSpacing.gapHXs,
                            Text(
                              b.category.label,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapHSm,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            AppSpacing.gapHXs,
                            Text(
                              status.statusText,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVMd,

                  // Business Name & Verified
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          style: AppTypography.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      if (b.verificationStatus ==
                          BusinessVerificationStatus.verified) ...[
                        AppSpacing.gapHSm,
                        const Tooltip(
                          message: 'Verified Local Business',
                          child: Icon(
                            AppIcons.verified,
                            color: AppColors.indigo600,
                            size: 22,
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.gapVXs,

                  // Locality, Distance & Address
                  Row(
                    children: [
                      Icon(
                        AppIcons.location,
                        size: 16,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                      AppSpacing.gapHXs,
                      Expanded(
                        child: Text(
                          b.distance != null
                              ? '${b.locationSummary} • ${b.distance}'
                              : b.locationSummary,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (b.address != null && b.address!.isNotEmpty) ...[
                    AppSpacing.gapVXs,
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text(
                        b.address!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                  AppSpacing.gapVLg,

                  // ── Actions Row ────────────────────────────────────────────
                  if ((b.contactPhone != null && b.contactPhone!.isNotEmpty) ||
                      (b.website != null && b.website!.isNotEmpty)) ...[
                    Row(
                      children: [
                        if (b.contactPhone != null &&
                            b.contactPhone!.isNotEmpty)
                          Expanded(
                            child: AppButton(
                              text: 'Call',
                              prefixIcon: AppIcons.phoneCall,
                              variant: AppButtonVariant.primary,
                              onPressed: () {
                                AppSnackbar.showInfo(
                                  context,
                                  message:
                                      'Public business contact: ${b.contactPhone}',
                                );
                              },
                            ),
                          ),
                        if (b.contactPhone != null &&
                            b.contactPhone!.isNotEmpty &&
                            b.website != null &&
                            b.website!.isNotEmpty)
                          AppSpacing.gapHSm,
                        if (b.website != null && b.website!.isNotEmpty)
                          Expanded(
                            child: AppButton(
                              text: 'Website',
                              prefixIcon: AppIcons.website,
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                AppSnackbar.showInfo(
                                  context,
                                  message: 'Website: ${b.website}',
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    AppSpacing.gapVLg,
                  ],

                  // ── Description ────────────────────────────────────────────
                  Text(
                    'About this Business',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  AppSpacing.gapVSm,
                  Text(
                    b.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  AppSpacing.gapVLg,

                  // ── Operating Hours Accordion ──────────────────────────────
                  if (b.operatingHours != null) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(
                              () => _isHoursExpanded = !_isHoursExpanded,
                            ),
                            child: Row(
                              children: [
                                const Icon(AppIcons.schedule, size: 20),
                                AppSpacing.gapHSm,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Operating Hours',
                                        style:
                                            AppTypography.titleSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        status.statusText,
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _isHoursExpanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                ),
                              ],
                            ),
                          ),
                          if (_isHoursExpanded) ...[
                            const Divider(),
                            AppSpacing.gapVXs,
                            _buildDayRow('Monday', b.operatingHours?.monday),
                            _buildDayRow('Tuesday', b.operatingHours?.tuesday),
                            _buildDayRow(
                              'Wednesday',
                              b.operatingHours?.wednesday,
                            ),
                            _buildDayRow(
                              'Thursday',
                              b.operatingHours?.thursday,
                            ),
                            _buildDayRow('Friday', b.operatingHours?.friday),
                            _buildDayRow(
                              'Saturday',
                              b.operatingHours?.saturday,
                            ),
                            _buildDayRow('Sunday', b.operatingHours?.sunday),
                          ],
                        ],
                      ),
                    ),
                    AppSpacing.gapVLg,
                  ],

                  // ── Services / Offerings ───────────────────────────────────
                  if (b.services.isNotEmpty) ...[
                    Text(
                      'Products & Services Offered',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    AppSpacing.gapVSm,
                    ...b.services.map((svc) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      svc.name,
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (svc.description != null &&
                                        svc.description!.isNotEmpty) ...[
                                      AppSpacing.gapVXs,
                                      Text(
                                        svc.description!,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (svc.startingPrice != null) ...[
                                AppSpacing.gapHSm,
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceContainerHigh
                                        : AppColors.lightSurfaceContainer,
                                    borderRadius: AppRadius.chip,
                                  ),
                                  child: Text(
                                    '₹${svc.startingPrice!.toInt()}',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.indigo600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    AppSpacing.gapVLg,
                  ],

                  // ── Business Owner / Locality Profile ──────────────────────
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppAvatar(
                              name: b.owner.displayName,
                              imageUrl: b.owner.avatarUrl,
                              size: AppAvatarSize.s48,
                            ),
                            AppSpacing.gapHMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.owner.displayName,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AppSpacing.gapVXs,
                                  Text(
                                    'Business Owner • ${b.owner.locality ?? b.locality ?? 'Aaspaas'}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapVSm,
                        AppButton(
                          text: 'Message Business Owner',
                          prefixIcon: AppIcons.comment,
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            try {
                              final repo =
                                  ref.read(messagingRepositoryProvider);
                              final conv = await repo
                                  .createOrGetConversation(b.owner.id);
                              if (context.mounted) {
                                context.push('/messages/${conv.id}');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackbar.showError(
                                  context,
                                  message:
                                      'Unable to start conversation with business owner.',
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapVXxl,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderHeader(bool isDark, BusinessEntity b) {
    return Container(
      height: 200,
      width: double.infinity,
      color: isDark
          ? AppColors.darkSurfaceContainerHigh
          : AppColors.lightSurfaceContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              b.category.icon,
              size: 48,
              color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
            ),
            AppSpacing.gapVSm,
            Text(
              b.category.label,
              style: AppTypography.labelLarge.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(String day, DayScheduleEntity? schedule) {
    String text;
    if (schedule == null || schedule.isClosed || schedule.intervals.isEmpty) {
      text = 'Closed';
    } else {
      text = schedule.intervals.map((i) => '${i.open} - ${i.close}').join(', ');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: text == 'Closed' ? AppColors.slate500 : null,
              fontWeight:
                  text == 'Closed' ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
