import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/app_dialog.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../application/services_controller.dart';
import '../../data/repositories/services_repository.dart';
import '../../domain/entities/service_category.dart';
import '../../domain/entities/service_listing_entity.dart';

class EditServiceScreen extends ConsumerStatefulWidget {
  const EditServiceScreen({required this.service, super.key});

  final ServiceListingEntity service;

  @override
  ConsumerState<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends ConsumerState<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _startingPriceController;
  late TextEditingController _experienceYearsController;
  late TextEditingController _localityController;
  late TextEditingController _cityController;
  late TextEditingController _serviceRadiusController;
  late TextEditingController _serviceAreaDescController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _whatsappController;

  late ServiceCategory _selectedCategory;
  late PricingModel _selectedPricingModel;
  late ServiceStatus _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _titleController = TextEditingController(text: s.title);
    _descriptionController = TextEditingController(text: s.description);
    _startingPriceController = TextEditingController(
      text: s.startingPrice != null ? s.startingPrice!.toString() : '',
    );
    _experienceYearsController = TextEditingController(
      text: s.experienceYears != null ? s.experienceYears!.toString() : '',
    );
    _localityController = TextEditingController(text: s.locality ?? '');
    _cityController = TextEditingController(text: s.city ?? '');
    _serviceRadiusController = TextEditingController(
      text: s.serviceRadiusKm != null ? s.serviceRadiusKm!.toString() : '',
    );
    _serviceAreaDescController =
        TextEditingController(text: s.serviceAreaDescription ?? '');
    _phoneController = TextEditingController(text: s.contactPhone ?? '');
    _emailController = TextEditingController(text: s.contactEmail ?? '');
    _whatsappController = TextEditingController(text: s.contactWhatsapp ?? '');
    _selectedCategory = s.category;
    _selectedPricingModel = s.pricingModel;
    _selectedStatus = s.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startingPriceController.dispose();
    _experienceYearsController.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _serviceRadiusController.dispose();
    _serviceAreaDescController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(servicesRepositoryProvider);

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'category': _selectedCategory.value,
        'pricingModel': _selectedPricingModel.value,
        'description': _descriptionController.text.trim(),
        'startingPrice': _startingPriceController.text.trim().isNotEmpty &&
                _selectedPricingModel != PricingModel.contactForQuote
            ? double.tryParse(_startingPriceController.text.trim())
            : null,
        'experienceYears': _experienceYearsController.text.trim().isNotEmpty
            ? int.tryParse(_experienceYearsController.text.trim())
            : null,
        'locality': _localityController.text.trim(),
        'city': _cityController.text.trim(),
        'serviceRadiusKm': _serviceRadiusController.text.trim().isNotEmpty
            ? double.tryParse(_serviceRadiusController.text.trim())
            : null,
        'serviceAreaDescription':
            _serviceAreaDescController.text.trim().isNotEmpty
                ? _serviceAreaDescController.text.trim()
                : null,
        'contactPhone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'contactEmail': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'contactWhatsapp': _whatsappController.text.trim().isNotEmpty
            ? _whatsappController.text.trim()
            : null,
      };

      final updated = await repo.updateService(widget.service.id, payload);

      if (_selectedStatus != widget.service.status) {
        await repo.updateServiceStatus(widget.service.id, _selectedStatus);
      }

      ref
          .read(servicesControllerProvider.notifier)
          .updateServiceInList(updated);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Service listing updated successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.showError(
          context,
          message:
              'Failed to update service: ${e.toString().replaceAll('Exception:', '')}',
        );
      }
    }
  }

  Future<void> _deleteService() async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete Service',
      message:
          'Are you sure you want to remove this service listing? Neighbors will no longer be able to find it.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: AppIcons.delete,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(servicesRepositoryProvider);
        await repo.deleteService(widget.service.id);
        ref
            .read(servicesControllerProvider.notifier)
            .removeService(widget.service.id);

        if (mounted) {
          AppSnackbar.showInfo(
            context,
            message: 'Service listing deleted.',
          );
          context.go('/services');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(
            context,
            message: 'Failed to delete: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Service'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.delete, color: AppColors.rose500),
            tooltip: 'Delete Service',
            onPressed: _deleteService,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status & Availability',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              DropdownButtonFormField<ServiceStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Listing Status',
                  border: OutlineInputBorder(),
                ),
                items: ServiceStatus.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
              ),
              AppSpacing.gapVLg,
              Text(
                'Service Information',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Service Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().length < 3 ? 'Required' : null,
              ),
              AppSpacing.gapVMd,
              DropdownButtonFormField<ServiceCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: ServiceCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 18),
                        AppSpacing.gapHSm,
                        Text(cat.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().length < 10
                    ? 'At least 10 chars'
                    : null,
              ),
              AppSpacing.gapVLg,
              Text(
                'Pricing & Experience',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              DropdownButtonFormField<PricingModel>(
                initialValue: _selectedPricingModel,
                decoration: const InputDecoration(
                  labelText: 'Pricing Structure *',
                  border: OutlineInputBorder(),
                ),
                items: PricingModel.values.map((pm) {
                  return DropdownMenuItem(
                    value: pm,
                    child: Text(pm.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPricingModel = val);
                },
              ),
              AppSpacing.gapVMd,
              Row(
                children: [
                  if (_selectedPricingModel !=
                      PricingModel.contactForQuote) ...[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _startingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    AppSpacing.gapHSm,
                  ],
                  Expanded(
                    child: TextFormField(
                      controller: _experienceYearsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Experience (Yrs)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVLg,
              Text(
                'Location & Service Area',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _localityController,
                decoration: const InputDecoration(
                  labelText: 'Base Locality *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              AppSpacing.gapVMd,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _serviceRadiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius (km)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  AppSpacing.gapHSm,
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _serviceAreaDescController,
                      decoration: const InputDecoration(
                        labelText: 'Coverage Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVLg,
              Text(
                'Public Contact Info',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Public Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'Public WhatsApp',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Public Email',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVXxl,
              AppButton(
                text: 'Save Changes',
                isFullWidth: true,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
              AppSpacing.gapVLg,
            ],
          ),
        ),
      ),
    );
  }
}
