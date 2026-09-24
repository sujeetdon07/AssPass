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
import '../../application/businesses_controller.dart';
import '../../data/repositories/businesses_repository.dart';
import '../../domain/entities/business_category.dart';

class CreateBusinessScreen extends ConsumerStatefulWidget {
  const CreateBusinessScreen({super.key});

  @override
  ConsumerState<CreateBusinessScreen> createState() =>
      _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends ConsumerState<CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _localityController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _imageUrlController = TextEditingController();

  // Primary service
  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();

  BusinessCategory _selectedCategory = BusinessCategory.foodDining;
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
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _imageUrlController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(businessesRepositoryProvider);

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _selectedCategory.value,
        'description': _descriptionController.text.trim(),
        if (_addressController.text.trim().isNotEmpty)
          'address': _addressController.text.trim(),
        if (_localityController.text.trim().isNotEmpty)
          'locality': _localityController.text.trim(),
        if (_cityController.text.trim().isNotEmpty)
          'city': _cityController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'contactPhone': _phoneController.text.trim(),
        if (_emailController.text.trim().isNotEmpty)
          'contactEmail': _emailController.text.trim(),
        if (_websiteController.text.trim().isNotEmpty)
          'website': _websiteController.text.trim(),
        'timezone': 'Asia/Kolkata',
        'operatingHours': {
          'monday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'tuesday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'wednesday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'thursday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'friday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'saturday': {
            'isClosed': false,
            'intervals': [
              {'open': '09:00', 'close': '21:00'},
            ],
          },
          'sunday': {
            'isClosed': false,
            'intervals': [
              {'open': '10:00', 'close': '20:00'},
            ],
          },
        },
        if (_imageUrlController.text.trim().isNotEmpty)
          'images': [
            {'url': _imageUrlController.text.trim(), 'displayOrder': 0},
          ],
        if (_serviceNameController.text.trim().isNotEmpty)
          'services': [
            {
              'name': _serviceNameController.text.trim(),
              'startingPrice':
                  double.tryParse(_servicePriceController.text.trim()),
            }
          ],
      };

      final created = await repo.createBusiness(payload);

      // Refresh list
      ref
          .read(businessesControllerProvider.notifier)
          .loadBusinesses(isRefresh: true);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Business created successfully!',
        );
        context.pushReplacement('/businesses/${created.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppSnackbar.showError(
          context,
          message:
              'Failed to create business: ${e.toString().replaceAll('Exception:', '')}',
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
        title: const Text('Register Business'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basic Info ────────────────────────────────────────────────
              Text(
                'Business Overview',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  hintText: 'e.g. Royal Sweets & Bakery',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Please enter a business name (at least 2 characters)';
                  }
                  return null;
                },
              ),
              AppSpacing.gapVMd,

              // Category Dropdown
              DropdownButtonFormField<BusinessCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Primary Category *',
                  border: OutlineInputBorder(),
                ),
                items: BusinessCategory.values.map((cat) {
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
                      'Tell neighbors what your business offers, specialties, atmosphere...',
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

              // ── Location ──────────────────────────────────────────────────
              Text(
                'Location & Address',
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
                  labelText: 'Locality *',
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
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Street Address (Public)',
                  hintText: 'e.g. #14, 100ft Road, near Metro',
                  border: OutlineInputBorder(),
                ),
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
                'Only contact details intended for customers should be entered here.',
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
                  labelText: 'Business Phone (Public)',
                  hintText: 'e.g. +918012345678',
                  prefixIcon: Icon(AppIcons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Business Email (Public)',
                  hintText: 'e.g. orders@myshop.in',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website / Instagram Link',
                  hintText: 'e.g. https://instagram.com/myshop',
                  prefixIcon: Icon(AppIcons.website),
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVLg,

              // ── Image Showcase ────────────────────────────────────────────
              Text(
                'Showcase Image',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Cover Image URL',
                  hintText: 'https://images.unsplash.com/...',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVLg,

              // ── Products / Services Offered ────────────────────────────────
              Text(
                'Highlight a Product or Service',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _serviceNameController,
                      decoration: const InputDecoration(
                        labelText: 'Item / Service Name',
                        hintText: 'e.g. Filter Coffee',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  AppSpacing.gapHSm,
                  Expanded(
                    child: TextFormField(
                      controller: _servicePriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹)',
                        hintText: 'e.g. 40',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapVXxl,

              // ── Submit Button ──────────────────────────────────────────────
              AppButton(
                text: 'Register Business',
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
