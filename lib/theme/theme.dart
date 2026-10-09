import 'package:flutter/material.dart';

import 'colors.dart';

/// App theme: "calm finance". One accent, hairlines instead of shadows,
/// IBM Plex Sans (bundled; tabular digits by default so amounts align).
class AppTheme {
  AppTheme._();

  static const String fontFamily = 'IBMPlexSans';

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: AppColors.mist,
        surface: AppColors.paper,
        ink: AppColors.ink,
        accent: AppColors.ledgerGreen,
        ledger: LedgerColors.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: AppColors.nightBackground,
        surface: AppColors.nightSurface,
        ink: AppColors.nightInk,
        accent: AppColors.nightGreen,
        ledger: LedgerColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color ink,
    required Color accent,
    required LedgerColors ledger,
  }) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.ledgerGreen,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: isLight ? Colors.white : AppColors.nightBackground,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: ledger.muted,
      outline: ledger.hairline,
      outlineVariant: ledger.hairline,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: background,
      surfaceContainerHigh: ledger.subtleFill,
      surfaceContainerHighest: ledger.subtleFill,
      error: ledger.moneyOut,
    );

    final text = _textTheme(ink, ledger.muted);
    final controlShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: ledger.hairline,
      extensions: [ledger],
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.lg,
        titleTextStyle: text.titleLarge,
      ),

      cardTheme: CardTheme(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.container),
          side: BorderSide(color: ledger.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(color: ledger.hairline, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
        minVerticalPadding: Space.md,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: text.bodyMedium?.copyWith(color: ledger.muted),
        iconColor: ledger.muted,
        selectedColor: accent,
        selectedTileColor: ledger.subtleFill,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: ledger.muted),
        hintStyle: TextStyle(color: ledger.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: ledger.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: ledger.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          side: BorderSide(color: ledger.hairline),
          foregroundColor: ink,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.container)),
        extendedTextStyle: text.labelLarge,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ledger.subtleFill,
          selectedForegroundColor: ink,
          side: BorderSide(color: ledger.hairline),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: ledger.subtleFill,
        side: BorderSide(color: ledger.hairline),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(color: ink),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: ledger.subtleFill,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => text.labelMedium?.copyWith(
              color: states.contains(WidgetState.selected) ? ink : ledger.muted,
              fontWeight:
                  states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? accent : ledger.muted,
            )),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: ledger.subtleFill,
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: ledger.muted),
        selectedLabelTextStyle:
            text.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: ledger.muted),
      ),

      tabBarTheme: TabBarTheme(
        labelColor: ink,
        unselectedLabelColor: ledger.muted,
        indicatorColor: accent,
        dividerColor: ledger.hairline,
        labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.labelLarge,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? scheme.onPrimary : ledger.muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : ledger.subtleFill),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : ledger.hairline),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: ledger.hairline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.container)),
        titleTextStyle: text.titleLarge,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? AppColors.ink : AppColors.nightInk,
        contentTextStyle: text.bodyMedium?.copyWith(
            color: isLight ? Colors.white : AppColors.nightBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.control)),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? AppColors.ink : AppColors.nightInk,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: text.bodySmall?.copyWith(
            color: isLight ? Colors.white : AppColors.nightBackground),
      ),

      badgeTheme: BadgeThemeData(backgroundColor: accent, textColor: scheme.onPrimary),
    );
  }

  /// Type scale (roughly a 1.2 ratio). Headings are semi-bold, never black;
  /// body copy stays regular so amounts carry the weight.
  static TextTheme _textTheme(Color ink, Color muted) {
    TextStyle s(double size, FontWeight w, {double height = 1.35, double ls = 0, Color? c}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: ls,
          color: c ?? ink,
        );
    return TextTheme(
      displaySmall: s(34, FontWeight.w600, height: 1.15, ls: -0.6),
      headlineMedium: s(28, FontWeight.w600, height: 1.2, ls: -0.4),
      headlineSmall: s(22, FontWeight.w600, height: 1.25, ls: -0.2),
      titleLarge: s(19, FontWeight.w600, height: 1.3, ls: -0.1),
      titleMedium: s(16, FontWeight.w600),
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(15, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45),
      bodySmall: s(12.5, FontWeight.w400, height: 1.4, c: muted),
      labelLarge: s(14, FontWeight.w500),
      labelMedium: s(12.5, FontWeight.w500),
      labelSmall: s(11.5, FontWeight.w500, c: muted),
    );
  }
}
