import 'package:flutter/material.dart';

/// Brand palette ("calm finance"). Widgets should not read these directly:
/// use `Theme.of(context).colorScheme` or `context.ledger` (below), which
/// switch correctly between light and dark mode.
class AppColors {
  AppColors._();

  // Light.
  static const Color mist = Color(0xFFF3F6F4); // page background
  static const Color paper = Color(0xFFFFFFFF); // surfaces
  static const Color ink = Color(0xFF16241F); // primary text
  static const Color slate = Color(0xFF5E6E68); // secondary text
  static const Color hairline = Color(0xFFDCE3DF); // dividers, borders
  static const Color ledgerGreen = Color(0xFF0F5D4C); // the one accent
  static const Color moneyIn = Color(0xFF1D7A4E);
  static const Color moneyOut = Color(0xFFB0442E);
  static const Color amber = Color(0xFF9A5B0C);

  // Dark.
  static const Color nightBackground = Color(0xFF0F1714);
  static const Color nightSurface = Color(0xFF16201C);
  static const Color nightInk = Color(0xFFE6EDEA);
  static const Color nightSlate = Color(0xFF93A39D);
  static const Color nightHairline = Color(0xFF26332E);
  static const Color nightGreen = Color(0xFF5CC2A6);
  static const Color nightMoneyIn = Color(0xFF6BCB98);
  static const Color nightMoneyOut = Color(0xFFE88A75);
  static const Color nightAmber = Color(0xFFE0A54F);
}

/// Semantic colours the Material scheme doesn't have.
/// Read with `context.ledger.moneyIn` etc.
@immutable
class LedgerColors extends ThemeExtension<LedgerColors> {
  const LedgerColors({
    required this.moneyIn,
    required this.moneyOut,
    required this.warning,
    required this.muted,
    required this.hairline,
    required this.subtleFill,
  });

  final Color moneyIn;
  final Color moneyOut;
  final Color warning;

  /// Secondary text (labels, currency symbol, cents).
  final Color muted;
  final Color hairline;

  /// Very light fill for selected rows, status pills, input backgrounds.
  final Color subtleFill;

  static const light = LedgerColors(
    moneyIn: AppColors.moneyIn,
    moneyOut: AppColors.moneyOut,
    warning: AppColors.amber,
    muted: AppColors.slate,
    hairline: AppColors.hairline,
    subtleFill: Color(0xFFEAF0ED),
  );

  static const dark = LedgerColors(
    moneyIn: AppColors.nightMoneyIn,
    moneyOut: AppColors.nightMoneyOut,
    warning: AppColors.nightAmber,
    muted: AppColors.nightSlate,
    hairline: AppColors.nightHairline,
    subtleFill: Color(0xFF1D2A25),
  );

  @override
  LedgerColors copyWith({
    Color? moneyIn,
    Color? moneyOut,
    Color? warning,
    Color? muted,
    Color? hairline,
    Color? subtleFill,
  }) =>
      LedgerColors(
        moneyIn: moneyIn ?? this.moneyIn,
        moneyOut: moneyOut ?? this.moneyOut,
        warning: warning ?? this.warning,
        muted: muted ?? this.muted,
        hairline: hairline ?? this.hairline,
        subtleFill: subtleFill ?? this.subtleFill,
      );

  @override
  LedgerColors lerp(ThemeExtension<LedgerColors>? other, double t) {
    if (other is! LedgerColors) return this;
    return LedgerColors(
      moneyIn: Color.lerp(moneyIn, other.moneyIn, t)!,
      moneyOut: Color.lerp(moneyOut, other.moneyOut, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      subtleFill: Color.lerp(subtleFill, other.subtleFill, t)!,
    );
  }
}

extension LedgerThemeContext on BuildContext {
  LedgerColors get ledger => Theme.of(this).extension<LedgerColors>() ?? LedgerColors.light;
}

/// Spacing scale (4-pt). Use these instead of ad-hoc numbers.
class Space {
  Space._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii by role: containers are softer than controls.
class Radii {
  Radii._();
  static const double control = 10; // buttons, inputs
  static const double container = 14; // cards, sheets
  static const double pill = 999; // chips, status
}
