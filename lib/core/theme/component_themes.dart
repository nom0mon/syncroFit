import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Reusable component theme definitions matching the Figma monochrome design.
///
/// Auth screens: clean thin borders on white. Dashboard: bordered dark cards.
/// Bottom nav: rounded pill shape with dark background.
abstract final class ComponentThemes {
  /// Elevated button — dark charcoal background, full-width, rounded.
  static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: AppColors.grey900,
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Input decoration — thin grey border, no fill, clean look.
  static InputDecorationTheme inputDecorationTheme(ColorScheme colorScheme) {
    return const InputDecorationTheme(
      filled: false,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.grey900, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
      hintStyle: TextStyle(color: AppColors.grey500),
    );
  }

  /// Card theme for light mode — white with thin grey border.
  static CardThemeData cardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.grey300),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  /// Card theme for dark mode — lighter fill with visible border for readability.
  static CardThemeData cardThemeDark() {
    return CardThemeData(
      color: const Color(0xFF262626),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3D3D3D), width: 1),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  /// App bar — transparent, no elevation.
  static AppBarTheme appBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
      titleTextStyle: AppTextStyles.titleLarge.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    );
  }

  /// Navigation bar — icon-only with white active / grey inactive, labels hidden.
  static NavigationBarThemeData navigationBarTheme(ColorScheme colorScheme) {
    return NavigationBarThemeData(
      backgroundColor: AppColors.navBarFill,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          );
        }
        return const TextStyle(
          fontSize: 11,
          color: AppColors.iconInactive,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white, size: 24);
        }
        return const IconThemeData(color: AppColors.iconInactive, size: 24);
      }),
    );
  }

  /// Input decoration for dark mode — grey borders, no chromatic error colors.
  static InputDecorationTheme inputDecorationThemeDark() {
    return const InputDecorationTheme(
      filled: false,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.containerBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.containerBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.focusBorder, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.containerBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: AppColors.focusBorder, width: 1),
      ),
      hintStyle: TextStyle(color: AppColors.textHint),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      errorStyle: TextStyle(color: AppColors.textPrimary),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive state helpers
  // ---------------------------------------------------------------------------

  /// Pressed state decoration — 20% white overlay on dark surfaces.
  static BoxDecoration pressedStateDecoration({
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return BoxDecoration(
      color: AppColors.pressedOverlay,
      borderRadius: borderRadius,
    );
  }

  /// Focused state decoration — 1px white border for keyboard/accessibility focus.
  static BoxDecoration focusedStateDecoration({
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return BoxDecoration(
      border: Border.all(color: AppColors.focusBorder, width: 1),
      borderRadius: borderRadius,
    );
  }

  /// Disabled opacity value — 40% white for disabled interactive elements.
  static const double disabledOpacity = 0.4;
}
