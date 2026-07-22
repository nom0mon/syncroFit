import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text style definitions for the SyncroFit app.
///
/// These are base styles that get merged into the app's [TextTheme].
/// Colors are intentionally omitted so they inherit from the active theme.
///
/// Uses the Geist font family for all styles. If Geist fails to load,
/// google_fonts automatically falls back to the platform default sans-serif.
abstract final class AppTextStyles {
  // ---------------------------------------------------------------------------
  // Heading / Title styles (formerly Poppins → now Geist)
  // ---------------------------------------------------------------------------

  static final TextStyle headlineLarge = _geistStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static final TextStyle headlineMedium = _geistStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static final TextStyle headlineSmall = _geistStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static final TextStyle titleLarge = _geistStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static final TextStyle titleMedium = _geistStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  );

  static final TextStyle titleSmall = _geistStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  // ---------------------------------------------------------------------------
  // Body / Label / Caption styles (formerly Inter → now Geist)
  // ---------------------------------------------------------------------------

  static final TextStyle bodyLarge = _geistStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  static final TextStyle bodyMedium = _geistStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
  );

  static final TextStyle bodySmall = _geistStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  static final TextStyle labelLarge = _geistStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = _geistStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static final TextStyle labelSmall = _geistStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  static final TextStyle caption = _geistStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
  );

  /// Attempts to create a Geist font style, falling back to the platform
  /// default sans-serif if the font is unavailable (satisfies Requirement 1.4).
  static TextStyle _geistStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required double letterSpacing,
  }) {
    try {
      return GoogleFonts.getFont(
        'Geist',
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Section Header style (Geist Mono — monospaced)
  // ---------------------------------------------------------------------------

  /// Monospaced section header style for uppercase dashboard labels.
  /// Falls back to platform monospace if Geist Mono is unavailable.
  static final TextStyle sectionHeader = _geistMonoStyle();

  static TextStyle _geistMonoStyle() {
    try {
      return GoogleFonts.getFont(
        'Geist Mono',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      );
    } catch (_) {
      // Geist Mono may not be in the google_fonts registry; fall back to
      // platform monospace (matches Requirement 1.4 fallback behavior).
      return const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      );
    }
  }

  /// Constructs the full [TextTheme] from these styles.
  static TextTheme get textTheme => TextTheme(
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
