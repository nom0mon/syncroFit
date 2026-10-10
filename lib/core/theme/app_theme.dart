import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'component_themes.dart';

/// Provides the light and dark [ThemeData] objects for the SyncroFit app.
///
/// Brand palette: navy `#142D4E`, blue `#3478F6`, lime `#C6F135`.
/// Light theme: white surfaces, navy text, blue interactive elements.
/// Dark theme: navy scaffold, white text, blue primary actions, lime accent.
abstract final class AppTheme {
  /// Light theme — white background, navy text, blue primary actions.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: Brightness.light,
      primary: AppColors.brandBlue,
      onPrimary: Colors.white,
      secondary: AppColors.brandNavy,
      onSecondary: Colors.white,
      tertiary: AppColors.brandLime,
      onTertiary: AppColors.brandNavy,
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

  /// Dark theme — navy background, white text, blue primary, lime accent.
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.brandBlue,
      onPrimary: Colors.white,
      secondary: AppColors.brandLime,
      onSecondary: AppColors.brandNavy,
      tertiary: AppColors.brandLime,
      onTertiary: AppColors.brandNavy,
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
