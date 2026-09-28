import 'dart:async';
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
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/chips/app_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_search_bar.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/repositories/auth_repository.dart';
import '../../../nearby/domain/services/location_service.dart';
import '../../../onboarding/data/repositories/onboarding_repository.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/app_media_service.dart';
import '../../../../shared/widgets/media/app_square_crop_dialog.dart';

/// State of username availability check.
enum UsernameAvailabilityState {
  idle,
  checking,
  available,
  unavailable,
  invalid,
  error,
}

/// Preset avatars for quick selection.
const _kAvatarPresets = [
  'https://api.dicebear.com/7.x/bottts/png?seed=Alex',
  'https://api.dicebear.com/7.x/bottts/png?seed=Maya',
  'https://api.dicebear.com/7.x/bottts/png?seed=Karan',
  'https://api.dicebear.com/7.x/bottts/png?seed=Priya',
  'https://api.dicebear.com/7.x/bottts/png?seed=Rohan',
  'https://api.dicebear.com/7.x/bottts/png?seed=Ananya',
];

/// Screen allowing authenticated neighbors to edit their profile details:
/// Display Name, Bio, Avatar / Profile Photo, and Locality.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _neighborhoodController;

  Timer? _debounceTimer;
  UsernameAvailabilityState _usernameState = UsernameAvailabilityState.idle;
  String? _usernameMessage;
  String _initialUsername = '';

  String? _selectedAvatarUrl;
  String? _selectedLocality;
  String? _selectedCity;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedCountryCode;

  bool _isSaving = false;
  String? _displayNameError;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    _displayNameController =
        TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _neighborhoodController =
        TextEditingController(text: user?.neighborhood ?? '');

    final initialU = user?.username ?? '';
    _initialUsername = initialU;
    _usernameController = TextEditingController(text: initialU);
    if (initialU.isNotEmpty) {
      _usernameState = UsernameAvailabilityState.available;
      _usernameMessage = 'Your current username';
    }

    _selectedAvatarUrl = user?.avatarUrl;
    _selectedLocality = user?.locality;
    _selectedCity = user?.city;
    _selectedState = user?.state;
    _selectedDistrict = user?.district;
    _selectedCountryCode = user?.countryCode ?? 'IN';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _neighborhoodController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounceTimer?.cancel();
    final clean = value.trim().startsWith('@')
        ? value.trim().substring(1).trim()
        : value.trim();

    if (clean.isEmpty) {
      setState(() {
        _usernameState = UsernameAvailabilityState.idle;
        _usernameMessage = null;
      });
      return;
    }

    if (clean.toLowerCase() == _initialUsername.toLowerCase()) {
      setState(() {
        _usernameState = UsernameAvailabilityState.available;
        _usernameMessage = 'Your current username';
      });
      return;
    }

    // Client-side format validation
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
    if (!regex.hasMatch(clean)) {
      setState(() {
        _usernameState = UsernameAvailabilityState.invalid;
        if (clean.length < 3) {
          _usernameMessage = 'Must be at least 3 characters';
        } else if (clean.length > 30) {
          _usernameMessage = 'Must be 30 characters or fewer';
        } else {
          _usernameMessage = 'Only letters, numbers, and _ allowed';
        }
      });
      return;
    }

    setState(() {
      _usernameState = UsernameAvailabilityState.checking;
      _usernameMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await ref
            .read(authRepositoryProvider)
            .checkUsernameAvailability(clean);

        if (!mounted) return;
        final currentText = _usernameController.text.trim();
        final currentClean = currentText.startsWith('@')
            ? currentText.substring(1).trim()
            : currentText;

        if (currentClean.toLowerCase() != clean.toLowerCase()) {
          return;
        }

        setState(() {
          if (result.available) {
            _usernameState = UsernameAvailabilityState.available;
            _usernameMessage = 'Username is available';
          } else {
            _usernameState = UsernameAvailabilityState.unavailable;
            _usernameMessage = result.message ?? 'Username already taken';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _usernameState = UsernameAvailabilityState.error;
          _usernameMessage = 'Error checking username';
        });
      }
    });
  }

  Widget? _buildUsernameStatusIndicator(bool isDark) {
    switch (_usernameState) {
      case UsernameAvailabilityState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case UsernameAvailabilityState.available:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppColors.emerald500,
            size: 20,
          ),
        );
      case UsernameAvailabilityState.unavailable:
      case UsernameAvailabilityState.invalid:
      case UsernameAvailabilityState.error:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(
            Icons.cancel_rounded,
            color: AppColors.rose500,
            size: 20,
          ),
        );
      case UsernameAvailabilityState.idle:
        return null;
    }
  }

  void _openAvatarPicker() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.lightOutlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                AppSpacing.gapVMd,
                Text(
                  'Choose Profile Picture',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                AppSpacing.gapVXs,
                Text(
                  'Pick a stylized avatar or enter a custom photo link',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                AppSpacing.gapVMd,
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final url in _kAvatarPresets)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAvatarUrl = url;
                          });
                          Navigator.pop(bottomSheetContext);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedAvatarUrl == url
                                  ? (isDark
                                      ? AppColors.darkPrimary
                                      : AppColors.lightPrimary)
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: AppAvatar(
                            imageUrl: url,
                            size: AppAvatarSize.s56,
                          ),
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapVLg,
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Upload Photo',
                        variant: AppButtonVariant.outlined,
                        prefixIcon: Icons.photo_library_rounded,
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _pickAndUploadAvatar();
                        },
                      ),
                    ),
                    if (_selectedAvatarUrl != null) ...[
                      AppSpacing.gapHSm,
                      Expanded(
                        child: AppButton(
                          text: 'Use Initials',
                          variant: AppButtonVariant.text,
                          onPressed: () {
                            setState(() {
                              _selectedAvatarUrl = null;
                            });
                            Navigator.pop(bottomSheetContext);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final mediaService = ref.read(appMediaServiceProvider);
    final pickedFile = await mediaService.pickSingleImage(
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );

    if (pickedFile == null || !mounted) return;

    final croppedFile = await AppSquareCropDialog.show(context, pickedFile);
    if (croppedFile == null || !mounted) return;

    try {
      AppSnackbar.showInfo(
        context,
        message: 'Optimizing and uploading profile photo...',
      );
      final result = await mediaService.uploadImage(croppedFile, type: 'avatar');
      if (mounted) {
        setState(() {
          _selectedAvatarUrl = result.url;
        });
        AppSnackbar.showSuccess(context, message: 'Profile photo selected.');
      }
    } catch (e) {
      debugPrint('[EditProfileScreen] Avatar upload failed: $e');
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Failed to upload photo. Please check your connection.',
        );
      }
    }
  }

  void _openLocalityChangeModal() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _LocalityPickerSheet(
          onLocalitySelected: (suggestion) {
            setState(() {
              _selectedLocality = suggestion.locality;
              _selectedCity = suggestion.city;
              _selectedState = suggestion.state;
              _selectedDistrict = suggestion.district;
              _selectedCountryCode = suggestion.countryCode;
            });
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final name = _displayNameController.text.trim();
    if (name.length < 2 || name.length > 50) {
      setState(() {
        _displayNameError = 'Name must be between 2 and 50 characters.';
      });
      return;
    }

    final rawUsername = _usernameController.text.trim();
    final cleanUsername = rawUsername.startsWith('@')
        ? rawUsername.substring(1).trim()
        : rawUsername;

    if (cleanUsername.isNotEmpty) {
      if (_usernameState == UsernameAvailabilityState.invalid ||
          _usernameState == UsernameAvailabilityState.unavailable ||
          _usernameState == UsernameAvailabilityState.error) {
        AppSnackbar.showError(
          context,
          message:
              _usernameMessage ?? 'Please choose a valid and available username.',
        );
        return;
      }
      if (_usernameState == UsernameAvailabilityState.checking) {
        AppSnackbar.showInfo(
          context,
          message: 'Please wait while we verify username availability...',
        );
        return;
      }
    }

    setState(() {
      _displayNameError = null;
      _isSaving = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
            username: cleanUsername.isNotEmpty ? cleanUsername.toLowerCase() : null,
            displayName: name,
            bio: _bioController.text.trim(),
            avatarUrl: _selectedAvatarUrl,
            locality: _selectedLocality,
            city: _selectedCity,
            district: _selectedDistrict,
            state: _selectedState,
            countryCode: _selectedCountryCode,
            neighborhood: _neighborhoodController.text.trim().isNotEmpty
                ? _neighborhoodController.text.trim()
                : null,
          );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Profile updated successfully!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message:
              'Failed to update profile: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    final localityText = (_selectedLocality != null && _selectedCity != null)
        ? '$_selectedLocality, $_selectedCity'
        : (_selectedCity ?? _selectedLocality ?? 'Tap to select locality');

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back to Profile',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Profile',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.lightOutlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: AppButton(
            text: 'Save Changes',
            variant: AppButtonVariant.primary,
            isLoading: _isSaving,
            onPressed: _isSaving ? null : _handleSave,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.gapVMd,

                // Avatar Editor Section
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: _openAvatarPicker,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                          child: AppAvatar(
                            imageUrl: _selectedAvatarUrl,
                            name: _displayNameController.text,
                            size: AppAvatarSize.s72,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _openAvatarPicker,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.gapVSm,

                Center(
                  child: TextButton.icon(
                    onPressed: _openAvatarPicker,
                    icon: Icon(AppIcons.edit, size: 14, color: primaryColor),
                    label: Text(
                      'Change Profile Photo',
                      style: AppTypography.labelMedium.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                AppSpacing.gapVLg,

                // Full Name
                AppTextField(
                  controller: _displayNameController,
                  label: 'Full Name',
                  hint: 'e.g. Sujeet Sharma',
                  prefixIcon: AppIcons.profile,
                  errorText: _displayNameError,
                  onChanged: (_) {
                    if (_displayNameError != null) {
                      setState(() {
                        _displayNameError = null;
                      });
                    }
                  },
                ),

                AppSpacing.gapVMd,

                // Unique Public Username
                AppTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'your_username',
                  prefixWidget: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Text(
                      '@',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.darkPrimary
                            : AppColors.lightPrimary,
                      ),
                    ),
                  ),
                  suffixWidget: _buildUsernameStatusIndicator(isDark),
                  helperText: _usernameState ==
                          UsernameAvailabilityState.available
                      ? '✓ $_usernameMessage'
                      : (_usernameState == UsernameAvailabilityState.checking
                          ? 'Checking availability...'
                          : '3–30 characters: letters, numbers, or _'),
                  errorText: (_usernameState ==
                              UsernameAvailabilityState.invalid ||
                          _usernameState ==
                              UsernameAvailabilityState.unavailable ||
                          _usernameState == UsernameAvailabilityState.error)
                      ? _usernameMessage
                      : null,
                  onChanged: _onUsernameChanged,
                ),

                AppSpacing.gapVMd,

                // Bio / About You
                AppTextField(
                  controller: _bioController,
                  label: 'Bio / About You (Optional)',
                  hint:
                      'Introduce yourself to neighbors (e.g. Resident since 2021 • Gardening, yoga & evening walks)',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  helperText: 'Max 300 characters',
                ),

                AppSpacing.gapVMd,

                // Locality Picker Card
                Text(
                  'Your Locality',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                AppSpacing.gapVXs,
                InkWell(
                  borderRadius: AppRadius.card,
                  onTap: _openLocalityChangeModal,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurfaceVariant,
                      borderRadius: AppRadius.card,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutline
                            : AppColors.lightOutline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.location, color: primaryColor, size: 22),
                        AppSpacing.gapHMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localityText,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (_selectedState != null)
                                Text(
                                  _selectedState!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Change',
                            style: AppTypography.labelSmall.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                AppSpacing.gapVMd,

                // Society / Apartment
                AppTextField(
                  controller: _neighborhoodController,
                  label: 'Society, Apartment or Colony (Optional)',
                  hint: 'e.g. Antriksh Golf View, Tower B',
                  prefixIcon: AppIcons.home,
                ),

                AppSpacing.gapVMd,

                // Verification Transparency Box
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            AppIcons.verified,
                            color: AppColors.emerald500,
                            size: 18,
                          ),
                          AppSpacing.gapHSm,
                          Expanded(
                            child: Text(
                              'Member Verification Status',
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapVSm,
                      Text(
                        'Aaspaas verifies members via Mobile OTP and Locality pairing to protect local communities from spam and bots.',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          height: 1.3,
                        ),
                      ),
                      AppSpacing.gapVMd,
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppBadge(
                            label: 'Phone Verified (OTP)',
                            variant: AppBadgeVariant.success,
                            icon: AppIcons.check,
                          ),
                          AppBadge(
                            label: 'Locality Linked',
                            variant: AppBadgeVariant.neutral,
                            icon: AppIcons.location,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                AppSpacing.gapVLg,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet allowing user to search Indian localities or auto-detect GPS location.
class _LocalityPickerSheet extends ConsumerStatefulWidget {
  const _LocalityPickerSheet({required this.onLocalitySelected});

  final ValueChanged<LocalitySuggestion> onLocalitySelected;

  @override
  ConsumerState<_LocalityPickerSheet> createState() =>
      _LocalityPickerSheetState();
}

class _LocalityPickerSheetState extends ConsumerState<_LocalityPickerSheet> {
  final _searchController = TextEditingController();
  List<LocalitySuggestion> _results = [];
  bool _isSearching = false;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _loadPopular();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopular() async {
    final repo = ref.read(onboardingRepositoryProvider);
    final popular = await repo.getPopularLocalities();
    if (mounted) {
      setState(() {
        _results = popular;
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.trim().isEmpty) {
      _loadPopular();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final repo = ref.read(onboardingRepositoryProvider);
    final data = await repo.searchLocalities(query.trim());
    if (mounted) {
      setState(() {
        _results = data;
        _isSearching = false;
      });
    }
  }

  Future<void> _handleDetectLocation() async {
    setState(() => _isDetecting = true);
    try {
      final locService = ref.read(locationServiceProvider);
      final enabled = await locService.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          AppSnackbar.showWarning(context, message: 'Please enable GPS.');
        }
        return;
      }

      var perm = await locService.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await locService.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          AppSnackbar.showWarning(
            context,
            message: 'Location permission needed.',
          );
        }
        return;
      }

      final pos = await locService.getCurrentPosition();
      if (pos == null) return;

      final repo = ref.read(onboardingRepositoryProvider);
      final locality = await repo.fetchCurrentLocationLocality(
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (locality != null && mounted) {
        widget.onLocalitySelected(locality);
      }
    } finally {
      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.lightOutlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.gapVMd,
              Text(
                'Change Locality',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
              AppSpacing.gapVMd,
              AppSearchBar(
                controller: _searchController,
                hint: 'Search city, sector (e.g. Noida, Sasaram)',
                onChanged: _handleSearch,
              ),
              AppSpacing.gapVSm,
              Material(
                color: Colors.transparent,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.my_location_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  title: Text(
                    'Use Current Location (GPS)',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  trailing: _isDetecting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        )
                      : null,
                  onTap: _isDetecting ? null : _handleDetectLocation,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            leading: Icon(
                              AppIcons.location,
                              size: 18,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                            title: Text(
                              item.locality,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${item.city}, ${item.state}',
                              style: AppTypography.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            onTap: () {
                              widget.onLocalitySelected(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
