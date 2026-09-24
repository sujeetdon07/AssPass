import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/services_controller.dart';
import '../../data/repositories/services_repository.dart';
import '../../domain/entities/service_category.dart';

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startingPriceController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _localityController = TextEditingController();
  final _cityController = TextEditingController();
  final _serviceRadiusController = TextEditingController(text: '5');
  final _serviceAreaDescController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();

  ServiceCategory _selectedCategory = ServiceCategory.electrician;
  PricingModel _selectedPricingModel = PricingModel.startingAt;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    if (authState is AuthAuthenticated) {
      _localityController.text = authState.user.locality ?? '';
      _cityController.text = authState.user.city ?? '';
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(servicesRepositoryProvider);

      final payload = <String, dynamic>{
        'title': _titleController.text.trim(),
        'category': _selectedCategory.value,
        'pricingModel': _selectedPricingModel.value,
        'description': _descriptionController.text.trim(),
        if (_startingPriceController.text.trim().isNotEmpty &&
            _selectedPricingModel != PricingModel.contactForQuote)
          'startingPrice':
              double.tryParse(_startingPriceController.text.trim()),
        if (_experienceYearsController.text.trim().isNotEmpty)
          'experienceYears':
              int.tryParse(_experienceYearsController.text.trim()),
        if (_localityController.text.trim().isNotEmpty)
          'locality': _localityController.text.trim(),
        if (_cityController.text.trim().isNotEmpty)
          'city': _cityController.text.trim(),
        if (_serviceRadiusController.text.trim().isNotEmpty)
          'serviceRadiusKm':
              double.tryParse(_serviceRadiusController.text.trim()),
        if (_serviceAreaDescController.text.trim().isNotEmpty)
          'serviceAreaDescription': _serviceAreaDescController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'contactPhone': _phoneController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'contactEmail': _emailController.text.trim(),
        if (_whatsappController.text.trim().isNotEmpty)
          'contactWhatsapp': _whatsappController.text.trim(),
      };

      final created = await repo.createService(payload);

      // Refresh listings
      ref
          .read(servicesControllerProvider.notifier)
          .loadServices(isRefresh: true);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Service listing created successfully!',
        );
        context.pushReplacement('/services/${created.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message:
              'Failed to create service listing: ${e.toString().replaceAll('Exception:', '')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Service'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Overview ──────────────────────────────────────────────────
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

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Service Title *',
                  hintText: 'e.g. Expert Home Electrical Repairs & Wiring',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Please enter a service title (at least 3 characters)';
                  }
                  return null;
                },
              ),
              AppSpacing.gapVMd,

              // Category Dropdown
              DropdownButtonFormField<ServiceCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Service Category *',
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

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText:
                      'Describe what work you carry out, special skills, equipment used, and service terms...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Please enter a description (at least 10 characters)';
                  }
                  return null;
                },
              ),
              AppSpacing.gapVLg,

              // ── Pricing & Experience ──────────────────────────────────────
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

              // Pricing Model Dropdown
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

              // Starting Price & Experience Years
              Row(
                children: [
                  if (_selectedPricingModel !=
                      PricingModel.contactForQuote) ...[
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _startingPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              _selectedPricingModel == PricingModel.hourly
                                  ? 'Hourly Rate (₹)'
                                  : 'Starting Rate (₹)',
                          hintText: 'e.g. 350',
                          border: const OutlineInputBorder(),
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
                        hintText: 'e.g. 5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVLg,

              // ── Service Location & Coverage ───────────────────────────────
              Text(
                'Service Location & Coverage Area',
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
                  hintText: 'e.g. Indiranagar',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Locality is required'
                    : null,
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  hintText: 'e.g. Bengaluru',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'City is required'
                    : null,
              ),
              AppSpacing.gapVMd,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _serviceRadiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Coverage Radius (km)',
                        hintText: 'e.g. 10',
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
                        hintText: 'e.g. Up to 10km around Indiranagar',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVLg,

              // ── Public Contact Info ───────────────────────────────────────
              Text(
                'Public Contact Info',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVXs,
              Text(
                'Neighbors will use these details to contact you for service requests.',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Public)',
                  hintText: 'e.g. +919876543210',
                  prefixIcon: Icon(AppIcons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Number (Public)',
                  hintText: 'e.g. +919876543210',
                  prefixIcon: Icon(AppIcons.chat),
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Contact Email (Public)',
                  hintText: 'e.g. service@provider.com',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVXxl,

              // ── Submit Button ──────────────────────────────────────────────
              AppButton(
                text: 'Publish Service Listing',
                isFullWidth: true,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              AppSpacing.gapVLg,
            ],
          ),
        ),
      ),
    );
  }
}
