import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/core/theme/app_colors.dart';
import 'package:synchrofit/core/theme/app_theme.dart';

/// Validates the SyncroFit brand palette redesign.
///
/// Brand palette:
/// - Navy `#142D4E`
/// - Blue `#3478F6`
/// - Lime `#C6F135`
///
/// This supersedes the previous achromatic (greyscale) dark-theme property.
/// The redesign intentionally introduces chromatic brand colors, so the dark
/// theme is no longer greyscale; these tests pin the brand colors into the
/// generated [ThemeData] instead.
void main() {
  int channel(double value) => (value * 255).round().clamp(0, 255);

  String hex(Color c) => '#${channel(c.r).toRadixString(16).padLeft(2, '0')}'
          '${channel(c.g).toRadixString(16).padLeft(2, '0')}'
          '${channel(c.b).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();

  group('Brand palette constants', () {
    test('the three brand colors match the specified hex values', () {
      expect(hex(AppColors.brandNavy), '#142D4E');
      expect(hex(AppColors.brandBlue), '#3478F6');
      expect(hex(AppColors.brandLime), '#C6F135');
    });
  });

  group('Dark theme uses the brand palette', () {
    final scheme = AppTheme.darkTheme.colorScheme;

    test('primary is brand blue', () {
      expect(hex(scheme.primary), '#3478F6');
    });

    test('secondary/tertiary accent is brand lime', () {
      expect(hex(scheme.secondary), '#C6F135');
      expect(hex(scheme.tertiary), '#C6F135');
    });

    test('scaffold surface is a navy tone', () {
      // Navy family: blue channel is the dominant channel and green exceeds red.
      final s = scheme.surface;
      expect(channel(s.b) > channel(s.r), isTrue);
      expect(channel(s.g) >= channel(s.r), isTrue);
    });

    test('onPrimary stays white for contrast on blue', () {
      expect(hex(scheme.onPrimary), '#FFFFFF');
    });
  });

  group('Light theme uses the brand palette', () {
    final scheme = AppTheme.lightTheme.colorScheme;

    test('primary is brand blue', () {
      expect(hex(scheme.primary), '#3478F6');
    });

    test('onSurface text is brand navy', () {
      expect(hex(scheme.onSurface), '#142D4E');
    });
  });
}
