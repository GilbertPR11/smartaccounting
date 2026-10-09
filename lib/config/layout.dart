import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Window size classes, following Material 3's adaptive-layout guidance:
///   compact  < 600   → phones (portrait)            → bottom navigation bar
///   medium   600–1023 → tablets, foldables, small windows → navigation rail
///   expanded ≥ 1024  → laptops, monitors, landscape tablets → labelled sidebar
enum WindowSize { compact, medium, expanded }

class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  /// Width at which a single screen splits into list + detail panes.
  static const double twoPane = 900;

  static WindowSize of(double width) => width >= expanded
      ? WindowSize.expanded
      : width >= medium
          ? WindowSize.medium
          : WindowSize.compact;
}

extension ResponsiveContext on BuildContext {
  /// Size class of the whole window (use for app-level navigation chrome).
  WindowSize get windowSize => Breakpoints.of(MediaQuery.sizeOf(this).width);
}

/// Horizontal padding that keeps content at most [maxWidth] wide and centred,
/// while letting the scroll area (and scrollbar) span the full pane.
double sidePadding(double availableWidth, {double maxWidth = 960, double min = 16}) =>
    math.max(min, (availableWidth - maxWidth) / 2);
