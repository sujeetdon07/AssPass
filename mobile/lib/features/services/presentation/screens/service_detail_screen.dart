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
import '../../../../core/services/app_share_service.dart';
import '../../application/services_controller.dart';
import '../../data/repositories/services_repository.dart';
import '../../domain/entities/service_listing_entity.dart';
import '../widgets/report_service_dialog.dart';
import '../../../messaging/domain/repositories/messaging_repository.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({required this.serviceId, super.key});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  ServiceListingEntity? _service;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(servicesRepositoryProvider);
      final model = await repo.getServiceById(widget.serviceId);
      if (mounted) {
        setState(() {
          _service = model;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load service details. Please retry.';
        });
      }
    }
  }

  Future<void> _handleFavoriteToggle() async {
    if (_service == null) return;
    final current = _service!;
    final targetFav = !current.isFavorited;
    final targetCount =
        targetFav ? current.favoriteCount + 1 : current.favoriteCount - 1;

    setState(() {
      _service = ServiceListingEntity(
        id: current.id,
        providerId: current.providerId,
        provider: current.provider,
        businessId: current.businessId,
        businessName: current.businessName,
        title: current.title,
        description: current.description,
        category: current.category,
        pricingModel: current.pricingModel,
        startingPrice: current.startingPrice,
        currency: current.currency,
        experienceYears: current.experienceYears,
        status: current.status,
        countryCode: current.countryCode,
        state: current.state,
        district: current.district,
        city: current.city,
        locality: current.locality,
        neighborhood: current.neighborhood,
        contactPhone: current.contactPhone,
        contactEmail: current.contactEmail,
        contactWhatsapp: current.contactWhatsapp,
        serviceRadiusKm: current.serviceRadiusKm,
        serviceAreaDescription: current.serviceAreaDescription,
        favoriteCount: targetCount < 0 ? 0 : targetCount,
        isFavorited: targetFav,
        isProvider: current.isProvider,
        distance: current.distance,
        distanceMeters: current.distanceMeters,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
    });

    ref.read(servicesControllerProvider.notifier).toggleFavorite(current.id);
  }

  Future<void> _openReportDialog() async {
    if (_service == null) return;
    final reported = await ReportServiceDialog.show(
      context,
      serviceId: _service!.id,
      serviceTitle: _service!.title,
      onSubmit: (reason, details) async {
        final repo = ref.read(servicesRepositoryProvider);
        await repo.reportService(_service!.id, reason, details);
      },
    );

    if (reported == true && mounted) {
      AppSnackbar.showSuccess(
        context,
        message: 'Report submitted. Our team will review this service listing.',
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

    if (_errorMessage != null || _service == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: AppErrorState(
            title: 'Service Not Found',
            message:
                _errorMessage ?? 'This service listing could not be found.',
            onRetry: _loadService,
          ),
        ),
      );
    }

    final s = _service!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share service',
            onPressed: () => AppShareService.shareService(context, s),
          ),
          IconButton(
            icon: Icon(
              s.isFavorited ? AppIcons.like : AppIcons.likeOutline,
              color: s.isFavorited ? AppColors.rose500 : null,
            ),
            tooltip: s.isFavorited ? 'Remove Favorite' : 'Favorite',
            onPressed: _handleFavoriteToggle,
          ),
          PopupMenuButton<String>(
            icon: const Icon(AppIcons.more),
            onSelected: (val) {
              if (val == 'share') {
                AppShareService.shareService(context, s);
              } else if (val == 'send_in_aaspaas') {
                AppShareService.showSendInAaspaasSheet(
                  context,
                  AppShareService.buildServicePayload(s),
                );
              } else if (val == 'report') {
                _openReportDialog();
              } else if (val == 'edit') {
                context.push('/services/${s.id}/edit', extra: s).then((_) {
                  _loadService();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 18),
                    AppSpacing.gapHSm,
                    Text('Share via...'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'send_in_aaspaas',
                child: Row(
                  children: [
                    Icon(Icons.send_rounded, size: 18, color: Color(0xFF4F46E5)),
                    AppSpacing.gapHSm,
                    Text('Send in Aaspaas'),
                  ],
                ),
              ),
              if (s.isProvider)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(AppIcons.edit, size: 18),
                      AppSpacing.gapHSm,
                      Text('Edit Service'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(AppIcons.report, size: 18),
                    AppSpacing.gapHSm,
                    Text('Report Service'),
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
            // ── Category Banner Header ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xl,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.indigo950,
                          AppColors.slate900,
                        ]
                      : [
                          AppColors.indigo50,
                          AppColors.slate100,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkPrimary.withValues(alpha: 0.2)
                          : AppColors.lightPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s.category.icon,
                      size: 42,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                  ),
                  AppSpacing.gapVSm,
                  Text(
                    s.category.label,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkPrimary
                          : AppColors.lightPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // ── Service Details ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    s.title,
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  AppSpacing.gapVSm,

                  // Price and Experience Chips
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkPrimary.withValues(alpha: 0.15)
                              : AppColors.lightPrimary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          s.formattedPrice,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceContainerHigh
                              : AppColors.lightSurfaceContainer,
                          borderRadius: AppRadius.chip,
                        ),
                        child: Text(
                          s.pricingModel.label,
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      if (s.experienceYears != null && s.experienceYears! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainerHigh
                                : AppColors.lightSurfaceContainer,
                            borderRadius: AppRadius.chip,
                          ),
                          child: Text(
                            '${s.experienceYears} Years Experience',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  AppSpacing.gapVMd,

                  // Location & Distance
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
                          s.distance != null
                              ? '${s.locationSummary} • ${s.distance}'
                              : s.locationSummary,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVLg,

                  // ── Action Buttons ─────────────────────────────────────────
                  Row(
                    children: [
                      if (s.contactPhone != null &&
                          s.contactPhone!.isNotEmpty) ...[
                        Expanded(
                          child: AppButton(
                            text: 'Call',
                            prefixIcon: AppIcons.phoneCall,
                            variant: AppButtonVariant.primary,
                            onPressed: () {
                              AppSnackbar.showInfo(
                                context,
                                message: 'Service phone: ${s.contactPhone}',
                              );
                            },
                          ),
                        ),
                        AppSpacing.gapHSm,
                      ],
                      if (s.contactWhatsapp != null &&
                          s.contactWhatsapp!.isNotEmpty) ...[
                        Expanded(
                          child: AppButton(
                            text: 'WhatsApp',
                            prefixIcon: AppIcons.chat,
                            variant: AppButtonVariant.secondary,
                            onPressed: () {
                              AppSnackbar.showInfo(
                                context,
                                message: 'WhatsApp: ${s.contactWhatsapp}',
                              );
                            },
                          ),
                        ),
                        AppSpacing.gapHSm,
                      ],
                      Expanded(
                        child: AppButton(
                          text: 'Message',
                          prefixIcon: AppIcons.comment,
                          variant: AppButtonVariant.secondary,
                          onPressed: () async {
                            try {
                              final repo =
                                  ref.read(messagingRepositoryProvider);
                              final conv = await repo
                                  .createOrGetConversation(s.providerId);
                              if (context.mounted) {
                                context.push('/messages/${conv.id}');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackbar.showError(
                                  context,
                                  message:
                                      'Unable to start conversation with service provider.',
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapVLg,

                  // ── Description ────────────────────────────────────────────
                  Text(
                    'About this Service',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  AppSpacing.gapVSm,
                  Text(
                    s.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  AppSpacing.gapVLg,

                  // ── Service Coverage / Radius ──────────────────────────────
                  if (s.serviceRadiusKm != null ||
                      (s.serviceAreaDescription != null &&
                          s.serviceAreaDescription!.isNotEmpty)) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(AppIcons.location, size: 20),
                              AppSpacing.gapHSm,
                              Text(
                                'Service Coverage Area',
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.gapVSm,
                          if (s.serviceRadiusKm != null)
                            Text(
                              'Serves clients within ${s.serviceRadiusKm!.toInt()} km of ${s.locationSummary}',
                              style: AppTypography.bodyMedium,
                            ),
                          if (s.serviceAreaDescription != null &&
                              s.serviceAreaDescription!.isNotEmpty) ...[
                            AppSpacing.gapVXs,
                            Text(
                              s.serviceAreaDescription!,
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
                    AppSpacing.gapVLg,
                  ],

                  // ── Provider Profile Card ──────────────────────────────────
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppAvatar(
                              name: s.provider.displayName,
                              imageUrl: s.provider.avatarUrl,
                              size: AppAvatarSize.s48,
                            ),
                            AppSpacing.gapHMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.provider.displayName,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AppSpacing.gapVXs,
                                  Text(
                                    'Service Specialist • ${s.provider.locality ?? s.locality ?? 'Aaspaas'}',
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
                        if (s.businessId != null &&
                            s.businessName != null &&
                            s.businessName!.isNotEmpty) ...[
                          const Divider(),
                          AppSpacing.gapVXs,
                          InkWell(
                            onTap: () =>
                                context.push('/businesses/${s.businessId}'),
                            child: Row(
                              children: [
                                const Icon(
                                  AppIcons.business,
                                  size: 16,
                                  color: AppColors.indigo600,
                                ),
                                AppSpacing.gapHSm,
                                Expanded(
                                  child: Text(
                                    'Affiliated Business: ${s.businessName}',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: AppColors.indigo600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  AppIcons.chevronRight,
                                  size: 16,
                                  color: AppColors.indigo600,
                                ),
                              ],
                            ),
                          ),
                        ],
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
}
