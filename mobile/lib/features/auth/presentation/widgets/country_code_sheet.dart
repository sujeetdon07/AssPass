import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/feedback/app_bottom_sheet.dart';

class CountryCodeItem {
  const CountryCodeItem({
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.code,
  });

  final String name;
  final String dialCode;
  final String flag;
  final String code;
}

const supportedCountries = <CountryCodeItem>[
  CountryCodeItem(
    name: 'India',
    dialCode: '+91',
    flag: '🇮🇳',
    code: 'IN',
  ),
  CountryCodeItem(
    name: 'United States',
    dialCode: '+1',
    flag: '🇺🇸',
    code: 'US',
  ),
  CountryCodeItem(
    name: 'United Kingdom',
    dialCode: '+44',
    flag: '🇬🇧',
    code: 'GB',
  ),
  CountryCodeItem(
    name: 'United Arab Emirates',
    dialCode: '+971',
    flag: '🇦🇪',
    code: 'AE',
  ),
  CountryCodeItem(
    name: 'Singapore',
    dialCode: '+65',
    flag: '🇸🇬',
    code: 'SG',
  ),
  CountryCodeItem(
    name: 'Australia',
    dialCode: '+61',
    flag: '🇦🇺',
    code: 'AU',
  ),
  CountryCodeItem(
    name: 'Canada',
    dialCode: '+1',
    flag: '🇨🇦',
    code: 'CA',
  ),
];

class CountryCodeSheet extends StatelessWidget {
  const CountryCodeSheet({
    super.key,
    required this.selectedDialCode,
    required this.onSelected,
  });

  final String selectedDialCode;
  final ValueChanged<CountryCodeItem> onSelected;

  static Future<CountryCodeItem?> show(
    BuildContext context, {
    required String selectedDialCode,
  }) {
    return AppBottomSheet.show<CountryCodeItem>(
      context: context,
      title: 'Select Country Code',
      child: Builder(
        builder: (ctx) => CountryCodeSheet(
          selectedDialCode: selectedDialCode,
          onSelected: (country) => Navigator.of(ctx).pop(country),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: supportedCountries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final country = supportedCountries[index];
        final isSelected = country.dialCode == selectedDialCode;

        return ListTile(
          leading: Text(
            country.flag,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            country.name,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                country.dialCode,
                style: AppTypography.labelLarge.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              if (isSelected) ...[
                AppSpacing.gapHSm,
                Icon(
                  AppIcons.check,
                  size: 18,
                  color:
                      isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                ),
              ],
            ],
          ),
          onTap: () => onSelected(country),
        );
      },
    );
  }
}
