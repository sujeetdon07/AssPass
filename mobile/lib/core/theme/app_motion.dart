import 'package:flutter/material.dart';

/// Centralized motion and animation tokens for Aaspaas.
///
/// Ensures subtle, restrained, and consistent transitions across
/// navigation, dialogs, button presses, and component states.
class AppMotion {
  AppMotion._();

  // ── Durations ──────────────────────────────────────────────────────────────

  /// Fast transitions (150ms) — Micro-interactions, ripples, button states
  static const Duration fast = Duration(milliseconds: 150);

  /// Normal transitions (250ms) — Tab shifts, sheet reveals, card expansions
  static const Duration normal = Duration(milliseconds: 250);

  /// Slow transitions (400ms) — Page navigation, modal entrances
  static const Duration slow = Duration(milliseconds: 400);

  // ── Curves ─────────────────────────────────────────────────────────────────

  /// Standard curve for general on-screen movement
  static const Curve standard = Curves.easeInOutCubic;

  /// Emphasized curve for entering or prominent elements
  static const Curve emphasized = Curves.easeOutCubic;

  /// Decelerating curve for elements entering from off-screen
  static const Curve decelerate = Curves.easeOut;

  /// Accelerating curve for elements exiting off-screen
  static const Curve accelerate = Curves.easeIn;
}
