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

  /// Very subtle ambient shadow for light theme
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x081E293B),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// Signature soft dimensional clay-inspired shadow for elevated cards
  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0C1E293B),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x061E293B),
      offset: Offset(0, 1),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// Medium component shadow (e.g. dropdowns, floating panels)
  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x0F0F172A),
      offset: Offset(0, 4),
      blurRadius: 10,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x080F172A),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  /// High elevation shadow (modals, bottom sheets)
  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x140F172A),
      offset: Offset(0, 12),
      blurRadius: 28,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
  ];

  /// Soft vibrant indigo glow shadow for primary Floating Action Buttons
  static const List<BoxShadow> shadowFab = [
    BoxShadow(
      color: Color(0x384F46E5),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x184F46E5),
      offset: Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  /// Soft top/bottom navigation bar shadow
  static const List<BoxShadow> shadowBar = [
    BoxShadow(
      color: Color(0x0A1E293B),
      offset: Offset(0, -3),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Subtle dark theme card shadow
  static const List<BoxShadow> shadowDarkCard = [
    BoxShadow(
      color: Color(0x30000000),
      offset: Offset(0, 4),
      blurRadius: 14,
      spreadRadius: -2,
    ),
  ];
}
