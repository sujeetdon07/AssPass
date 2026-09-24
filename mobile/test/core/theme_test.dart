import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aaspaas/core/storage/local_storage_service.dart';
import 'package:aaspaas/core/theme/app_colors.dart';
import 'package:aaspaas/core/theme/app_elevation.dart';
import 'package:aaspaas/core/theme/app_icons.dart';
import 'package:aaspaas/core/theme/app_motion.dart';
import 'package:aaspaas/core/theme/app_radius.dart';
import 'package:aaspaas/core/theme/app_spacing.dart';
import 'package:aaspaas/core/theme/app_theme.dart';
import 'package:aaspaas/core/theme/app_typography.dart';
import 'package:aaspaas/core/theme/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Design Tokens', () {
    test('AppColors palette defines required primary, secondary, tertiary', () {
      expect(AppColors.indigo600, isNotNull);
      expect(AppColors.violet600, isNotNull);
      expect(AppColors.teal600, isNotNull);
      expect(AppColors.lightPrimary, isNotNull);
      expect(AppColors.darkPrimary, isNotNull);
    });

    test('AppSpacing defines restrained grid scale', () {
      expect(AppSpacing.none, 0.0);
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 40.0);
      expect(AppSpacing.xxxl, 48.0);
      expect(AppSpacing.huge, 64.0);
    });

    test('AppRadius defines restrained geometry', () {
      expect(AppRadius.none, 0.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.pill, 999.0);
      expect(AppRadius.card, AppRadius.borderMd);
      expect(AppRadius.button, AppRadius.borderMd);
    });

    test('AppElevation defines subtle elevations', () {
      expect(AppElevation.none, 0.0);
      expect(AppElevation.low, 1.0);
      expect(AppElevation.medium, 3.0);
      expect(AppElevation.high, 6.0);
    });

    test('AppIcons provides centralized icon definitions', () {
      expect(AppIcons.home, isNotNull);
      expect(AppIcons.nearby, isNotNull);
      expect(AppIcons.communities, isNotNull);
      expect(AppIcons.marketplace, isNotNull);
      expect(AppIcons.profile, isNotNull);
    });

    test('AppMotion defines standard animation tokens', () {
      expect(AppMotion.fast, const Duration(milliseconds: 150));
      expect(AppMotion.normal, const Duration(milliseconds: 250));
      expect(AppMotion.slow, const Duration(milliseconds: 400));
    });

    test('AppTypography builds Material 3 text hierarchy', () {
      final lightTextTheme = AppTypography.createTextTheme(Brightness.light);
      final darkTextTheme = AppTypography.createTextTheme(Brightness.dark);

      expect(lightTextTheme.displayLarge, isNotNull);
      expect(lightTextTheme.headlineMedium, isNotNull);
      expect(lightTextTheme.titleLarge, isNotNull);
      expect(lightTextTheme.bodyMedium, isNotNull);
      expect(lightTextTheme.labelSmall, isNotNull);

      expect(darkTextTheme.bodyLarge, isNotNull);
    });
  });

  group('AppTheme', () {
    test('Light theme builds successfully with valid Material 3 config', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.lightPrimary);
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(theme.appBarTheme, isNotNull);
      expect(theme.navigationBarTheme, isNotNull);
      expect(theme.cardTheme, isNotNull);
      expect(theme.inputDecorationTheme, isNotNull);
    });

    test('Dark theme builds successfully with valid Material 3 config', () {
      final theme = AppTheme.darkTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.darkPrimary);
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
      expect(theme.appBarTheme, isNotNull);
      expect(theme.navigationBarTheme, isNotNull);
      expect(theme.cardTheme, isNotNull);
      expect(theme.inputDecorationTheme, isNotNull);
    });
  });

  group('ThemeModeNotifier', () {
    late SharedPreferences prefs;
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
    });

    test('defaults to ThemeMode.system when no saved preference', () {
      final controller = ThemeModeNotifier(storage);
      expect(controller.state, ThemeMode.system);
    });

    test('updates theme mode and persists to local storage', () async {
      final controller = ThemeModeNotifier(storage);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.state, ThemeMode.dark);
      expect(storage.readThemeMode(), 'dark');

      await controller.setThemeMode(ThemeMode.light);
      expect(controller.state, ThemeMode.light);
      expect(storage.readThemeMode(), 'light');

      await controller.setThemeMode(ThemeMode.system);
      expect(controller.state, ThemeMode.system);
      expect(storage.readThemeMode(), 'system');
    });

    test('loads persisted theme mode from local storage on init', () async {
      await storage.saveThemeMode('dark');
      final controller = ThemeModeNotifier(storage);
      expect(controller.state, ThemeMode.dark);
    });
  });
}
