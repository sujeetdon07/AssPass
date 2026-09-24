import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/buttons/app_icon_button.dart';
import '../../../../shared/widgets/buttons/app_text_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/layout/responsive_container.dart';
import '../../application/auth_controller.dart';
import '../widgets/otp_pin_input.dart';

/// Step 3 of onboarding: Verify 6-digit OTP sent to the user's mobile number.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.maskedPhoneNumber,
    this.initialDevOtp,
    this.cooldownSeconds = 60,
  });

  final String phoneNumber;
  final String maskedPhoneNumber;
  final String? initialDevOtp;
  final int cooldownSeconds;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  late int _remainingSeconds;
  Timer? _timer;
  String _enteredOtp = '';
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  String? _currentDevOtp;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.cooldownSeconds;
    _currentDevOtp = widget.initialDevOtp;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify(String otp) async {
    if (otp.length != 6) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(
            phoneNumber: widget.phoneNumber,
            otp: otp,
          );
      // If verification succeeds, GoRouter's redirect will automatically
      // navigate to /onboarding/profile (or /home if already onboarded).
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        AppSnackbar.showError(
          context,
          message: _errorMessage ?? 'Invalid verification code.',
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

  Future<void> _handleResend() async {
    if (_remainingSeconds > 0 || _isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.phoneNumber);

      if (mounted) {
        setState(() {
          _remainingSeconds = result.cooldownSeconds;
          _currentDevOtp = result.devOtp;
        });
        _startTimer();
        AppSnackbar.showSuccess(
          context,
          message: 'New verification code sent!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
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
          semanticLabel: 'Back to phone entry',
          onPressed: () => context.pop(),
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

                // Title
                Text(
                  'Verify your number',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),

                AppSpacing.gapVSm,

                // Masked Phone Display & Change Action
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      'Enter the 6-digit code sent to ${widget.maskedPhoneNumber}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Text(
                        'Change',
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                // Development OTP Banner (non-production helper)
                if (AppConfig.isDebugMode && _currentDevOtp != null) ...[
                  AppSpacing.gapVMd,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkPrimary.withValues(alpha: 0.15)
                          : AppColors.lightPrimary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.card,
                      border: Border.all(
                        color: (isDark
                                ? AppColors.darkPrimary
                                : AppColors.lightPrimary)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.info,
                          size: 18,
                          color: isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary,
                        ),
                        AppSpacing.gapHSm,
                        Expanded(
                          child: Text(
                            'Development Mode OTP: $_currentDevOtp',
                            style: AppTypography.labelMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.lightPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                AppSpacing.gapVLg,

                // 6-digit OTP PIN input
                OtpPinInput(
                  hasError: _hasError,
                  onChanged: (code) {
                    setState(() {
                      _enteredOtp = code;
                      if (_hasError) _hasError = false;
                    });
                  },
                  onCompleted: (code) => _handleVerify(code),
                ),

                if (_errorMessage != null) ...[
                  AppSpacing.gapVSm,
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color:
                          isDark ? AppColors.darkError : AppColors.lightError,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                AppSpacing.gapVLg,

                // Verify Button
                AppButton(
                  text: 'Verify and Continue',
                  variant: AppButtonVariant.primary,
                  isLoading: _isLoading,
                  onPressed: _enteredOtp.length == 6 && !_isLoading
                      ? () => _handleVerify(_enteredOtp)
                      : null,
                ),

                AppSpacing.gapVLg,

                // Resend Countdown
                Center(
                  child: _remainingSeconds > 0
                      ? Text(
                          'Resend code in ${_remainingSeconds}s',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        )
                      : AppTextButton(
                          text: 'Resend OTP',
                          onPressed: _isLoading ? null : _handleResend,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
