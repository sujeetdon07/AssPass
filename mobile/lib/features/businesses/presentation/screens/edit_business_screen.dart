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
import '../../application/businesses_controller.dart';
import '../../data/repositories/businesses_repository.dart';
import '../../domain/entities/business_category.dart';
import '../../domain/entities/business_entity.dart';

class EditBusinessScreen extends ConsumerStatefulWidget {
  const EditBusinessScreen({required this.business, super.key});

  final BusinessEntity business;

  @override
  ConsumerState<EditBusinessScreen> createState() => _EditBusinessScreenState();
}

class _EditBusinessScreenState extends ConsumerState<EditBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _addressController;
  late TextEditingController _localityController;
  late TextEditingController _cityController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;

  late BusinessCategory _selectedCategory;
  late BusinessStatus _selectedStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _nameController = TextEditingController(text: b.name);
    _descriptionController = TextEditingController(text: b.description);
    _addressController = TextEditingController(text: b.address ?? '');
    _localityController = TextEditingController(text: b.locality ?? '');
    _cityController = TextEditingController(text: b.city ?? '');
    _phoneController = TextEditingController(text: b.contactPhone ?? '');
    _emailController = TextEditingController(text: b.contactEmail ?? '');
    _websiteController = TextEditingController(text: b.website ?? '');
    _selectedCategory = b.category;
    _selectedStatus = b.status;
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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(businessesRepositoryProvider);

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _selectedCategory.value,
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'locality': _localityController.text.trim(),
        'city': _cityController.text.trim(),
        'contactPhone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'contactEmail': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'website': _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
      };

      final updated = await repo.updateBusiness(widget.business.id, payload);

      if (_selectedStatus != widget.business.status) {
        await repo.updateBusinessStatus(widget.business.id, _selectedStatus);
      }

      ref
          .read(businessesControllerProvider.notifier)
          .updateBusinessInList(updated);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Business listing updated successfully!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppSnackbar.showError(
          context,
          message:
              'Failed to update business: ${e.toString().replaceAll('Exception:', '')}',
        );
      }
    }
  }

  Future<void> _deleteBusiness() async {
    final confirmed = await AppDialog.show(
      context,
      title: 'Delete Business',
      message:
          'Are you sure you want to delete this business listing? It will no longer be visible to neighbors.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      icon: AppIcons.delete,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(businessesRepositoryProvider);
        await repo.deleteBusiness(widget.business.id);
        ref
            .read(businessesControllerProvider.notifier)
            .removeBusiness(widget.business.id);

        if (mounted) {
          AppSnackbar.showInfo(
            context,
            message: 'Business listing deleted.',
          );
          context.go('/businesses');
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
        title: const Text('Edit Business'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.delete, color: AppColors.rose500),
            tooltip: 'Delete Business',
            onPressed: _deleteBusiness,
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
                'Status & Visibility',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              DropdownButtonFormField<BusinessStatus>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Listing Status',
                  border: OutlineInputBorder(),
                ),
                items: BusinessStatus.values.map((s) {
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
                'General Details',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVSm,
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.trim().length < 2 ? 'Required' : null,
              ),
              AppSpacing.gapVMd,
              DropdownButtonFormField<BusinessCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
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
                'Location',
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
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVLg,
              Text(
                'Contact Details',
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Public Email',
                  border: OutlineInputBorder(),
                ),
              ),
              AppSpacing.gapVMd,
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: 'Website / Link',
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
