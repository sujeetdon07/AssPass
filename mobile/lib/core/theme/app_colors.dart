import 'package:flutter/material.dart';

/// Centralized color palette and semantic color tokens for Aaspaas.
///
/// Follows Material 3 color system with custom Aaspaas brand identity:
/// Indigo, Blue-Violet, Soft Lavender, Neutral Gray, and Deep Obsidian.
///
/// All UI components must use these tokens rather than raw [Color] values.
class AppColors {
  AppColors._();

  // ── Brand Primitives ───────────────────────────────────────────────────────

  /// Primary brand indigo
  static const Color indigo50 = Color(0xFFEEF2FF);
  static const Color indigo100 = Color(0xFFE0E7FF);
  static const Color indigo200 = Color(0xFFC7D2FE);
  static const Color indigo300 = Color(0xFFA5B4FC);
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5); // Primary brand anchor
  static const Color indigo700 = Color(0xFF4338CA);
  static const Color indigo800 = Color(0xFF3730A3);
  static const Color indigo900 = Color(0xFF312E81);
  static const Color indigo950 = Color(0xFF1E1B4B);

  /// Secondary brand violet / lavender
  static const Color violet50 = Color(0xFFF5F3FF);
  static const Color violet100 = Color(0xFFEDE9FE);
  static const Color violet200 = Color(0xFFDDD6FE);
  static const Color violet300 = Color(0xFFC4B5FD);
  static const Color violet400 = Color(0xFFA78BFA);
  static const Color violet500 = Color(0xFF8B5CF6);
  static const Color violet600 = Color(0xFF7C3AED); // Secondary brand anchor
  static const Color violet700 = Color(0xFF6D28D9);
  static const Color violet800 = Color(0xFF5B21B6);
  static const Color violet900 = Color(0xFF4C1D95);

  /// Tertiary teal (local community & discovery accent)
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);
  static const Color teal200 = Color(0xFF99F6E4);
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal600 = Color(0xFF0D9488); // Tertiary anchor
  static const Color teal900 = Color(0xFF134E4A);

  /// Neutral slate primitives
  static const Color slate25 = Color(0xFFFBFDFF);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF0B0F19); // Near-black obsidian

  // ── Status Primitives ──────────────────────────────────────────────────────

  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald900 = Color(0xFF064E3B);

  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber900 = Color(0xFF78350F);

  static const Color rose50 = Color(0xFFFEF2F2);
  static const Color rose100 = Color(0xFFFEE2E2);
  static const Color rose500 = Color(0xFFEF4444);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose700 = Color(0xFFB91C1C);
  static const Color rose900 = Color(0xFF7F1D1D);

  static const Color sky50 = Color(0xFFF0F9FF);
  static const Color sky100 = Color(0xFFE0F2FE);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color sky700 = Color(0xFF0369A1);
  static const Color sky900 = Color(0xFF0C4A6E);

  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // ── Light Theme Semantic Tokens ───────────────────────────────────────────

  static const Color lightPrimary = indigo600;
  static const Color lightOnPrimary = pureWhite;
  static const Color lightPrimaryContainer = indigo50;
  static const Color lightOnPrimaryContainer = indigo900;

  static const Color lightSecondary = violet600;
  static const Color lightOnSecondary = pureWhite;
  static const Color lightSecondaryContainer = violet50;
  static const Color lightOnSecondaryContainer = violet900;

  static const Color lightTertiary = teal600;
  static const Color lightOnTertiary = pureWhite;
  static const Color lightTertiaryContainer = teal50;
  static const Color lightOnTertiaryContainer = teal900;

  static const Color lightBackground = slate50;
  static const Color lightOnBackground = slate900;
  static const Color lightSurface = pureWhite;
  static const Color lightOnSurface = slate900;
  static const Color lightSurfaceContainerLow = slate50;
  static const Color lightSurfaceContainer = slate100;
  static const Color lightSurfaceContainerHigh = slate200;
  static const Color lightSurfaceVariant = slate100;
  static const Color lightOnSurfaceVariant = slate600;

  static const Color lightOutline = slate300;
  static const Color lightOutlineVariant = slate200;

  static const Color lightTextPrimary = slate900;
  static const Color lightTextSecondary = slate600;
  static const Color lightTextTertiary = slate400;
  static const Color lightTextDisabled = slate300;
  static const Color lightTextInverse = pureWhite;

  static const Color lightSuccess = emerald500;
  static const Color lightOnSuccess = pureWhite;
  static const Color lightSuccessContainer = emerald50;
  static const Color lightOnSuccessContainer = emerald700;

  static const Color lightWarning = amber500;
  static const Color lightOnWarning = pureWhite;
  static const Color lightWarningContainer = amber50;
  static const Color lightOnWarningContainer = amber700;

  static const Color lightError = rose500;
  static const Color lightOnError = pureWhite;
  static const Color lightErrorContainer = rose50;
  static const Color lightOnErrorContainer = rose700;

  static const Color lightInfo = sky500;
  static const Color lightOnInfo = pureWhite;
  static const Color lightInfoContainer = sky50;
  static const Color lightOnInfoContainer = sky700;

  // ── Dark Theme Semantic Tokens ────────────────────────────────────────────

  static const Color darkPrimary = indigo400;
  static const Color darkOnPrimary = indigo950;
  static const Color darkPrimaryContainer = indigo900;
  static const Color darkOnPrimaryContainer = indigo100;

  static const Color darkSecondary = violet400;
  static const Color darkOnSecondary = violet900;
  static const Color darkSecondaryContainer = violet900;
  static const Color darkOnSecondaryContainer = violet100;

  static const Color darkTertiary = teal400;
  static const Color darkOnTertiary = teal900;
  static const Color darkTertiaryContainer = teal900;
  static const Color darkOnTertiaryContainer = teal100;

  static const Color darkBackground = slate950; // Deep obsidian, NOT plain gray
  static const Color darkOnBackground = slate50;
  static const Color darkSurface = Color(0xFF111726);
  static const Color darkOnSurface = slate100;
  static const Color darkSurfaceContainerLow = Color(0xFF0D121F);
  static const Color darkSurfaceContainer = Color(0xFF161F33);
  static const Color darkSurfaceContainerHigh = Color(0xFF1E2A44);
  static const Color darkSurfaceVariant = Color(0xFF24304D);
  static const Color darkOnSurfaceVariant = slate400;

  static const Color darkOutline = slate700;
  static const Color darkOutlineVariant = slate800;

  static const Color darkTextPrimary = slate100;
  static const Color darkTextSecondary = slate400;
  static const Color darkTextTertiary = slate500;
  static const Color darkTextDisabled = slate700;
  static const Color darkTextInverse = slate950;

  static const Color darkSuccess = emerald500;
  static const Color darkOnSuccess = emerald900;
  static const Color darkSuccessContainer = Color(0xFF064E3B);
  static const Color darkOnSuccessContainer = emerald100;

  static const Color darkWarning = amber500;
  static const Color darkOnWarning = amber900;
  static const Color darkWarningContainer = Color(0xFF451A03);
  static const Color darkOnWarningContainer = amber100;

  static const Color darkError = rose500;
  static const Color darkOnError = rose900;
  static const Color darkErrorContainer = Color(0xFF4C0519);
  static const Color darkOnErrorContainer = rose100;

  static const Color darkInfo = sky500;
  static const Color darkOnInfo = sky900;
  static const Color darkInfoContainer = Color(0xFF082F49);
  static const Color darkOnInfoContainer = sky100;
}
