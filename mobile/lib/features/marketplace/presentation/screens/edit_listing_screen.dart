import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/listing_detail_controller.dart';
import '../../application/marketplace_controller.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../domain/entities/marketplace_category.dart';
import '../../domain/entities/marketplace_condition.dart';
import '../../domain/entities/marketplace_listing_entity.dart';
import '../../../../shared/widgets/media/app_multi_image_picker.dart';

/// Screen for editing an existing marketplace listing (owner only).
class EditListingScreen extends ConsumerStatefulWidget {
  const EditListingScreen({
    super.key,
    required this.listing,
  });

  final MarketplaceListingEntity listing;

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _localityController;

  late MarketplaceCategory _selectedCategory;
  late MarketplaceCondition _selectedCondition;
  late bool _isFree;
  bool _isSubmitting = false;
  String? _errorMessage;
  late final List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing.title);
    _descriptionController =
        TextEditingController(text: widget.listing.description);
    _priceController = TextEditingController(
      text:
          widget.listing.isFree ? '' : widget.listing.price.toInt().toString(),
    );
    _localityController =
        TextEditingController(text: widget.listing.locality ?? '');
    _selectedCategory = widget.listing.category;
    _selectedCondition = widget.listing.condition;
    _isFree = widget.listing.isFree;
    _imageUrls = widget.listing.images.map((img) => img.url).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final price =
        _isFree ? 0.0 : double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (!_isFree && price <= 0) {
      setState(
        () => _errorMessage =
            'Please enter a price greater than 0, or mark as Free.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(marketplaceRepositoryProvider);
      final images = _imageUrls
          .asMap()
          .entries
          .map((e) => {'url': e.value, 'displayOrder': e.key})
          .toList();

      await repo.updateListing(
        widget.listing.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory.value,
        price: price,
        condition: _selectedCondition.value,
        locality: _localityController.text.trim().isEmpty
            ? null
            : _localityController.text.trim(),
        images: images,
      );

      if (mounted) {
        ref
            .read(listingDetailControllerProvider(widget.listing.id).notifier)
            .loadListing();
        ref
            .read(marketplaceControllerProvider.notifier)
            .loadListings(refresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'Failed to update listing: ${e.toString().replaceAll("Exception:", "").trim()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ───────────────────────────────────────────────────
                Text(
                  'Listing Title',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.trim().length < 5) {
                      return 'Title must be at least 5 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Category ────────────────────────────────────────────────
                Text(
                  'Category',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                DropdownButtonFormField<MarketplaceCategory>(
                  initialValue: _selectedCategory,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: MarketplaceCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 18),
                          const SizedBox(width: AppSpacing.xs),
                          Text(cat.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Price ───────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price',
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        const Text('Giveaway / Free'),
                        Switch(
                          value: _isFree,
                          onChanged: (val) => setState(() => _isFree = val),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isFree) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (_isFree) return null;
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a price.';
                      }
                      final p = double.tryParse(val.trim());
                      if (p == null || p < 0) {
                        return 'Please enter a valid non-negative price.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),

                // ── Condition ───────────────────────────────────────────────
                Text(
                  'Condition',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                DropdownButtonFormField<MarketplaceCondition>(
                  initialValue: _selectedCondition,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: MarketplaceCondition.values.map((cond) {
                    return DropdownMenuItem(
                      value: cond,
                      child: Text(cond.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCondition = val);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Description ─────────────────────────────────────────────
                Text(
                  'Description',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 5000,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Description must be at least 10 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Images Area ─────────────────────────────────────────────
                AppMultiImagePicker(
                  label: 'Photos',
                  category: 'marketplace',
                  maxImages: 10,
                  initialUrls: _imageUrls,
                  onUrlsChanged: (urls) {
                    setState(() {
                      _imageUrls.clear();
                      _imageUrls.addAll(urls);
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Locality ────────────────────────────────────────────────
                Text(
                  'Locality',
                  style: AppTypography.titleSmall
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextFormField(
                  controller: _localityController,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: AppSpacing.xl),

                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.rose500),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Save Button ─────────────────────────────────────────────
                AppButton(
                  text: 'Save Changes',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
