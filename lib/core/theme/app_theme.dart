import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'component_themes.dart';

/// Provides the light and dark [ThemeData] objects for the SyncroFit app.
///
/// Light theme: clean white auth screens. Dark theme: black dashboard with
/// white text — pure monochrome, high contrast.
abstract final class AppTheme {
  /// Light theme — white background, dark text, used for auth/onboarding.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.textTheme,
      scaffoldBackgroundColor: Colors.white,
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: ComponentThemes.inputDecorationTheme(colorScheme),
      cardTheme: ComponentThemes.cardTheme(colorScheme),
      appBarTheme: ComponentThemes.appBarTheme(colorScheme),
      navigationBarTheme: ComponentThemes.navigationBarTheme(colorScheme),
    );
  }

  /// Dark theme — jet black background, white text, bordered cards.
  /// Pure monochrome Geist-inspired aesthetic with zero elevation.
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.textPrimary,
      onPrimary: AppColors.scaffoldBlack,
      secondary: AppColors.textSecondary,
      onSecondary: AppColors.scaffoldBlack,
      surface: AppColors.scaffoldBlack,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.cardFill,
      outline: AppColors.cardBorder,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTextStyles.textTheme,
      scaffoldBackgroundColor: AppColors.scaffoldBlack,
      elevatedButtonTheme: ComponentThemes.elevatedButtonTheme(colorScheme),
      inputDecorationTheme: ComponentThemes.inputDecorationThemeDark(),
      cardTheme: ComponentThemes.cardThemeDark(),
      appBarTheme: ComponentThemes.appBarTheme(colorScheme),
      navigationBarTheme: ComponentThemes.navigationBarTheme(colorScheme),
    );
  }
}
