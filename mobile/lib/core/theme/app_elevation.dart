import 'package:flutter/material.dart';

/// Centralized elevation and shadow tokens for Aaspaas.
///
/// Material 3 prioritizes tonal surface tinting over heavy shadows.
/// These elevation levels provide subtle, soft shadows for elevated
/// interactive components and floating elements.
class AppElevation {
  AppElevation._();

  // ── Raw Elevation Levels ───────────────────────────────────────────────────

  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 6.0;
  static const double level4 = 8.0;
  static const double level5 = 12.0;

  // ── Semantic Elevation ─────────────────────────────────────────────────────

  static const double none = level0;
  static const double low = level1;
  static const double medium = level2;
  static const double high = level3;

  // ── Subtle Box Shadow Helpers ──────────────────────────────────────────────

  /// Very subtle card shadow for light theme
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A0F172A), // 4% slate
      offset: Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];

  /// Medium component shadow (e.g. dropdowns, floating buttons)
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x0F0F172A), // 6% slate
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x0A0F172A), // 4% slate
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// High elevation shadow (modals, bottom sheets)
  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x140F172A), // 8% slate
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];
}
