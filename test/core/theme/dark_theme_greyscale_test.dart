import 'package:flutter/material.dart';
import 'package:glados/glados.dart';
import 'package:synchrofit/core/theme/app_colors.dart';
import 'package:synchrofit/core/theme/component_themes.dart';

/// **Validates: Requirements 2.6**
///
/// Property 1: Dark theme colors are achromatic
///
/// For any color value extracted from the dark theme's ColorScheme, CardTheme,
/// NavigationBarTheme, AppBarTheme, and InputDecorationTheme defaults, the
/// color's red, green, and blue channels SHALL be equal (R == G == B),
/// confirming a pure greyscale palette.
///
/// This test constructs the same ColorScheme and component themes used by
/// AppTheme.darkTheme (see lib/core/theme/app_theme.dart) without triggering
/// font loading, since the property under test is purely about color values.
void main() {
  // Same ColorScheme construction as AppTheme.darkTheme
  const darkColorScheme = ColorScheme.dark(
    primary: AppColors.textPrimary,
    onPrimary: AppColors.scaffoldBlack,
    secondary: AppColors.textSecondary,
    onSecondary: AppColors.scaffoldBlack,
    surface: AppColors.scaffoldBlack,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.cardFill,
    outline: AppColors.cardBorder,
  );

  /// Helper to check if a color is achromatic (R == G == B).
  /// Colors with zero alpha are ignored (transparent).
  bool isAchromatic(Color color) {
    if (color.a == 0) return true;
    return color.r == color.g && color.g == color.b;
  }

  int channel(double value) => (value * 255).round().clamp(0, 255);

  /// Extracts all explicitly-set colors from the dark theme for verification.
  List<MapEntry<String, Color>> extractDarkThemeColors() {
    final colors = <MapEntry<String, Color>>[];

    // ColorScheme — only the colors we explicitly set
    colors.add(MapEntry('colorScheme.primary', darkColorScheme.primary));
    colors.add(MapEntry('colorScheme.onPrimary', darkColorScheme.onPrimary));
    colors.add(MapEntry('colorScheme.secondary', darkColorScheme.secondary));
    colors
        .add(MapEntry('colorScheme.onSecondary', darkColorScheme.onSecondary));
    colors.add(MapEntry('colorScheme.surface', darkColorScheme.surface));
    colors.add(MapEntry('colorScheme.onSurface', darkColorScheme.onSurface));
    colors.add(MapEntry('colorScheme.surfaceContainerHighest',
        darkColorScheme.surfaceContainerHighest));
    colors.add(MapEntry('colorScheme.outline', darkColorScheme.outline));

    // CardTheme — same as ComponentThemes.cardThemeDark()
    final cardTheme = ComponentThemes.cardThemeDark();
    if (cardTheme.color != null) {
      colors.add(MapEntry('cardTheme.color', cardTheme.color!));
    }
    final cardShape = cardTheme.shape;
    if (cardShape is RoundedRectangleBorder &&
        cardShape.side != BorderSide.none) {
      colors.add(MapEntry('cardTheme.borderColor', cardShape.side.color));
    }

    // NavigationBarTheme — same as ComponentThemes.navigationBarTheme(colorScheme)
    final navBarTheme = ComponentThemes.navigationBarTheme(darkColorScheme);
    if (navBarTheme.backgroundColor != null) {
      colors.add(MapEntry(
          'navBarTheme.backgroundColor', navBarTheme.backgroundColor!));
    }
    // Check active/inactive icon colors via iconTheme resolver
    final iconTheme = navBarTheme.iconTheme;
    if (iconTheme != null) {
      final activeIconTheme = iconTheme.resolve({WidgetState.selected});
      final inactiveIconTheme = iconTheme.resolve(<WidgetState>{});
      if (activeIconTheme?.color != null) {
        colors.add(
            MapEntry('navBarTheme.activeIconColor', activeIconTheme!.color!));
      }
      if (inactiveIconTheme?.color != null) {
        colors.add(MapEntry(
            'navBarTheme.inactiveIconColor', inactiveIconTheme!.color!));
      }
    }

    // AppBarTheme — same as ComponentThemes.appBarTheme(colorScheme)
    final appBarTheme = ComponentThemes.appBarTheme(darkColorScheme);
    if (appBarTheme.backgroundColor != null &&
        appBarTheme.backgroundColor != Colors.transparent) {
      colors.add(MapEntry(
          'appBarTheme.backgroundColor', appBarTheme.backgroundColor!));
    }
    if (appBarTheme.foregroundColor != null) {
      colors.add(MapEntry(
          'appBarTheme.foregroundColor', appBarTheme.foregroundColor!));
    }

    // InputDecorationTheme — same as ComponentThemes.inputDecorationThemeDark()
    final inputTheme = ComponentThemes.inputDecorationThemeDark();
    _extractInputBorderColor(inputTheme.border, 'inputTheme.border', colors);
    _extractInputBorderColor(
        inputTheme.enabledBorder, 'inputTheme.enabledBorder', colors);
    _extractInputBorderColor(
        inputTheme.focusedBorder, 'inputTheme.focusedBorder', colors);
    _extractInputBorderColor(
        inputTheme.errorBorder, 'inputTheme.errorBorder', colors);
    _extractInputBorderColor(
        inputTheme.focusedErrorBorder, 'inputTheme.focusedErrorBorder', colors);
    if (inputTheme.hintStyle?.color != null) {
      colors.add(
          MapEntry('inputTheme.hintStyle.color', inputTheme.hintStyle!.color!));
    }
    if (inputTheme.labelStyle?.color != null) {
      colors.add(MapEntry(
          'inputTheme.labelStyle.color', inputTheme.labelStyle!.color!));
    }

    return colors;
  }

  group('Property 1: Dark theme colors are achromatic', () {
    test('all explicitly-set dark theme colors have R == G == B', () {
      final themeColors = extractDarkThemeColors();

      // Ensure we're actually testing something meaningful
      expect(themeColors.length, greaterThan(10),
          reason:
              'Should extract a significant number of colors from the dark theme');

      for (final entry in themeColors) {
        expect(
          isAchromatic(entry.value),
          isTrue,
          reason: '${entry.key} is not achromatic: '
              'R=${channel(entry.value.r)}, G=${channel(entry.value.g)}, B=${channel(entry.value.b)} '
              '(0x${entry.value.toARGB32().toRadixString(16).padLeft(8, '0')})',
        );
      }
    });

    Glados(any.intInRange(0, 100)).test(
      'any randomly-selected dark theme color index yields achromatic color',
      (index) {
        final colors = extractDarkThemeColors();
        if (colors.isEmpty) return;
        final entry = colors[index % colors.length];
        expect(
          isAchromatic(entry.value),
          isTrue,
          reason: '${entry.key} is not achromatic: '
              'R=${channel(entry.value.r)}, G=${channel(entry.value.g)}, B=${channel(entry.value.b)}',
        );
      },
    );
  });
}

/// Extracts the border color from an InputBorder if it's an OutlineInputBorder.
void _extractInputBorderColor(
  InputBorder? border,
  String name,
  List<MapEntry<String, Color>> colors,
) {
  if (border is OutlineInputBorder && border.borderSide != BorderSide.none) {
    colors.add(MapEntry('$name.color', border.borderSide.color));
  }
}
