import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';

/// Accessible 6-digit OTP PIN input with individual digit cells.
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  final int _length = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _currentCode =>
      _controllers.map((controller) => controller.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste
      final clean = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _length; i++) {
        if (i < clean.length) {
          _controllers[i].text = clean[i];
        }
      }
      final code = _currentCode;
      widget.onChanged?.call(code);
      if (code.length == _length) {
        widget.onCompleted(code);
        _focusNodes.last.unfocus();
      } else {
        _focusNodes[clean.length.clamp(0, _length - 1)].requestFocus();
      }
      return;
    }

    widget.onChanged?.call(_currentCode);

    if (value.isNotEmpty) {
      if (index < _length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_currentCode.length == _length) {
          widget.onCompleted(_currentCode);
        }
      }
    }
  }

  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_length, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: Focus(
            onKeyEvent: (node, event) => _handleKeyEvent(index, event),
            child: Semantics(
              label: 'Verification digit ${index + 1} of $_length',
              child: TextFormField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                autofocus: index == 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant,
                  contentPadding: EdgeInsets.zero,
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
                      color: widget.hasError
                          ? (isDark
                              ? AppColors.darkError
                              : AppColors.lightError)
                          : (isDark
                              ? AppColors.darkOutline
                              : AppColors.lightOutline),
                      width: widget.hasError ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide: BorderSide(
                      color: widget.hasError
                          ? (isDark
                              ? AppColors.darkError
                              : AppColors.lightError)
                          : (isDark
                              ? AppColors.darkPrimary
                              : AppColors.lightPrimary),
                      width: 2.0,
                    ),
                  ),
                ),
                onChanged: (value) => _onDigitChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}
