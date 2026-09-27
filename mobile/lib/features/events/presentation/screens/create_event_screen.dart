import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../application/events_controller.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/entities/event_category.dart';

/// Screen allowing users to create a new local community event.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.communityId});

  final String? communityId;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _localityController = TextEditingController();
  final _cityController = TextEditingController();
  final _imageUrlController = TextEditingController();

  EventCategory _selectedCategory = EventCategory.neighborhood;
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.add(const Duration(days: 1));
    _startTime = const TimeOfDay(hour: 10, minute: 0);
    _endDate = now.add(const Duration(days: 1));
    _endTime = const TimeOfDay(hour: 12, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _localityController.dispose();
    _cityController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startAt = _combineDateAndTime(_startDate, _startTime);
    final endAt = _combineDateAndTime(_endDate, _endTime);

    if (endAt.isBefore(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(eventsRepositoryProvider);
      final newEvent = await repository.createEvent(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory.value,
        startAt: startAt.toUtc().toIso8601String(),
        endAt: endAt.toUtc().toIso8601String(),
        venue: _venueController.text.trim(),
        address: _addressController.text.trim(),
        locality: _localityController.text.trim().isNotEmpty
            ? _localityController.text.trim()
            : null,
        city: _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        communityId: widget.communityId,
        coverImageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
      );

      ref.read(eventsControllerProvider.notifier).onEventCreated(newEvent);

      if (mounted) {
        context.pop();
        context.push('/events/${newEvent.id}', extra: newEvent);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host an Event'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title *',
                  hintText: 'e.g. Indiranagar Morning 5K Run',
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Title must be at least 3 characters.';
                  }
                  if (val.trim().length > 150) {
                    return 'Title cannot exceed 150 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Category Selector
              Text(
                'Category *',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: EventCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    avatar: Icon(cat.icon, size: 16),
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'What is this event about? Mention schedule, requirements, etc.',
                ),
                maxLines: 4,
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Description must be at least 10 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Date & Time Selectors
              Text(
                'When *',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(dateFormat.format(_startDate)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_startTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: _pickEndDate,
                      icon: const Icon(Icons.event_repeat_outlined, size: 16),
                      label: Text(dateFormat.format(_endDate)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.access_time_filled, size: 16),
                      label: Text(_endTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Location Section
              Text(
                'Where *',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(
                  labelText: 'Venue / Place Name *',
                  hintText: 'e.g. 12th Main Park Gate or Community Center',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Venue is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address Details *',
                  hintText: 'e.g. 12th Main Road, HAL 2nd Stage',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Address is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _localityController,
                      decoration: const InputDecoration(
                        labelText: 'Locality / Area',
                        hintText: 'e.g. Indiranagar',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'e.g. Bengaluru',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Optional Cover Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Cover Image URL (optional)',
                  hintText: 'https://example.com/banner.jpg',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish Event'),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
