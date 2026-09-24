import 'package:flutter/material.dart';

/// Centralized spacing tokens and layout helpers for Aaspaas.
///
/// Follows a strict 4pt/8pt geometric grid. Avoid arbitrary numbers
/// such as `SizedBox(height: 17)` or `EdgeInsets.all(13)`.
class AppSpacing {
  AppSpacing._();

  // ── Raw Spacing Values ─────────────────────────────────────────────────────

  static const double none = 0.0;
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double s12 = 12.0;
  static const double md = 16.0;
  static const double s20 = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;

  // ── EdgeInsets Helpers (All Sides) ─────────────────────────────────────────

  static const EdgeInsets insetNone = EdgeInsets.zero;
  static const EdgeInsets insetXs = EdgeInsets.all(xs);
  static const EdgeInsets insetSm = EdgeInsets.all(sm);
  static const EdgeInsets insetS12 = EdgeInsets.all(s12);
  static const EdgeInsets insetMd = EdgeInsets.all(md);
  static const EdgeInsets insetLg = EdgeInsets.all(lg);
  static const EdgeInsets insetXl = EdgeInsets.all(xl);

  // ── Symmetric Horizontal Insets ────────────────────────────────────────────

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // ── Symmetric Vertical Insets ──────────────────────────────────────────────

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  // ── Combined Screen Padding ────────────────────────────────────────────────

  /// Standard screen content padding (16 horizontal, 16 vertical)
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );

  /// Card internal padding (16 horizontal, 16 vertical)
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  /// Compact card internal padding (12 horizontal, 12 vertical)
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(s12);

  // ── Gap / SizedBox Spacers ─────────────────────────────────────────────────

  static const SizedBox gapHXxs = SizedBox(width: xxs);
  static const SizedBox gapHXs = SizedBox(width: xs);
  static const SizedBox gapHSm = SizedBox(width: sm);
  static const SizedBox gapHS12 = SizedBox(width: s12);
  static const SizedBox gapHMd = SizedBox(width: md);
  static const SizedBox gapHLg = SizedBox(width: lg);
  static const SizedBox gapHXl = SizedBox(width: xl);

  static const SizedBox gapVXxs = SizedBox(height: xxs);
  static const SizedBox gapVXs = SizedBox(height: xs);
  static const SizedBox gapVSm = SizedBox(height: sm);
  static const SizedBox gapVS12 = SizedBox(height: s12);
  static const SizedBox gapVMd = SizedBox(height: md);
  static const SizedBox gapVLg = SizedBox(height: lg);
  static const SizedBox gapVXl = SizedBox(height: xl);
  static const SizedBox gapVXxl = SizedBox(height: xxl);
}
