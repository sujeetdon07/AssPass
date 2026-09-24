import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/auth_controller.dart';
import '../widgets/country_code_sheet.dart';

/// Step 2 of onboarding: Enter mobile number for phone authentication.
class PhoneInputScreen extends ConsumerStatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _dialCode = '+91';
  String _flag = '🇮🇳';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _selectCountry() async {
    final selected = await CountryCodeSheet.show(
      context,
      selectedDialCode: _dialCode,
    );
    if (selected != null) {
      setState(() {
        _dialCode = selected.dialCode;
        _flag = selected.flag;
      });
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required.';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (_dialCode == '+91') {
      if (digits.length != 10) {
        return 'Please enter a 10-digit mobile number.';
      }
      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
        return 'Indian mobile numbers must start with 6, 7, 8, or 9.';
      }
    } else {
      if (digits.length < 7 || digits.length > 15) {
        return 'Please enter a valid phone number.';
      }
    }
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final rawDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullNumber = '$_dialCode$rawDigits';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .requestOtp(fullNumber);

      if (mounted) {
        context.push(
          AppRoutes.otp,
          extra: {
            'phoneNumber': fullNumber,
            'maskedPhoneNumber': result.maskedPhoneNumber,
            'devOtp': result.devOtp,
            'cooldownSeconds': result.cooldownSeconds,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        AppSnackbar.showError(
          context,
          message: _errorMessage ?? 'Failed to send verification code.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.arrowBack,
          semanticLabel: 'Back to welcome',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.gapVMd,

                  // Screen Title
                  Text(
                    'Enter your mobile number',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),

                  AppSpacing.gapVSm,

                  // Subtitle
                  Text(
                    'We will send a 6-digit verification code to verify your phone number.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),

                  AppSpacing.gapVLg,

                  // Phone Number Input Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country Code Selector Button
                      InkWell(
                        onTap: _selectCountry,
                        borderRadius: AppRadius.input,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.lightSurfaceVariant,
                            borderRadius: AppRadius.input,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _flag,
                                style: const TextStyle(fontSize: 20),
                              ),
                              AppSpacing.gapHXs,
                              Text(
                                _dialCode,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const Icon(AppIcons.arrowDropDown, size: 20),
                            ],
                          ),
                        ),
                      ),

                      AppSpacing.gapHSm,

                      // National Number Field
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          style: AppTypography.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            hintText: '98765 43210',
                            prefixIcon: const Icon(AppIcons.phone, size: 20),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.darkSurfaceVariant
                                : AppColors.lightSurfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.input,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkOutline
                                    : AppColors.lightOutline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppRadius.input,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkOutline
                                    : AppColors.lightOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: AppRadius.input,
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.darkPrimary
                                    : AppColors.lightPrimary,
                                width: 2.0,
                              ),
                            ),
                          ),
                          validator: _validatePhone,
                          onFieldSubmitted: (_) => _handleContinue(),
                        ),
                      ),
                    ],
                  ),

                  if (_errorMessage != null) ...[
                    AppSpacing.gapVSm,
                    Text(
                      _errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color:
                            isDark ? AppColors.darkError : AppColors.lightError,
                      ),
                    ),
                  ],

                  AppSpacing.gapVLg,

                  // Continue Action
                  AppButton(
                    text: 'Continue',
                    variant: AppButtonVariant.primary,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _handleContinue,
                  ),

                  AppSpacing.gapVLg,

                  // Privacy Notice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.privacy,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      AppSpacing.gapHSm,
                      Expanded(
                        child: Text(
                          'Your phone number is kept strictly confidential and will never be shared publicly on your profile.',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
