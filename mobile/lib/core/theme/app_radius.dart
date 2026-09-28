import 'package:flutter/material.dart';

/// Centralized corner radius tokens for Aaspaas.
///
/// Provides restrained, cohesive rounded geometry across cards,
/// buttons, dialogs, bottom sheets, and chips.
class AppRadius {
  AppRadius._();

  // ── Raw Values ─────────────────────────────────────────────────────────────

  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double pill = 999.0;

  // ── Radius Instances ───────────────────────────────────────────────────────

  static const Radius circularNone = Radius.zero;
  static const Radius circularXs = Radius.circular(xs);
  static const Radius circularSm = Radius.circular(sm);
  static const Radius circularMd = Radius.circular(md);
  static const Radius circularLg = Radius.circular(lg);
  static const Radius circularXl = Radius.circular(xl);
  static const Radius circularPill = Radius.circular(pill);

  // ── BorderRadius Instances ─────────────────────────────────────────────────

  static const BorderRadius borderNone = BorderRadius.zero;
  static const BorderRadius borderXs = BorderRadius.all(circularXs);
  static const BorderRadius borderSm = BorderRadius.all(circularSm);
  static const BorderRadius borderMd = BorderRadius.all(circularMd);
  static const BorderRadius borderLg = BorderRadius.all(circularLg);
  static const BorderRadius borderXl = BorderRadius.all(circularXl);
  static const BorderRadius borderPill = BorderRadius.all(circularPill);

  /// Top-only radius for bottom sheets and modal dialogs (28pt).
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(28.0),
  );

  /// Dialog corner radius (24pt)
  static const BorderRadius dialog = borderXl;

  /// Standard card corner radius (12pt)
  static const BorderRadius card = borderMd;

  /// Signature rounded clay card radius (24pt) matching modern soft 3D aesthetics
  static const BorderRadius cardClay = BorderRadius.all(Radius.circular(24.0));

  /// Standard button corner radius (12pt)
  static const BorderRadius button = borderMd;

  /// Pill badge / chip corner radius (999pt)
  static const BorderRadius chip = borderPill;

  /// Circular element radius
  static const BorderRadius circle = borderPill;

  /// Text field corner radius (16pt)
  static const BorderRadius input = borderLg;
}
