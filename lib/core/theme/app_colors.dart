import 'package:flutter/material.dart';

/// Named color constants for the SyncroFit palette.
///
/// Pure monochrome aesthetic — black, white, and greys only.
/// Geist-inspired dark palette with high-contrast dark cards and clean
/// white auth screens.
abstract final class AppColors {
  // Primary palette — monochrome
  static const Color primary = Color(0xFF1A1A1A);
  static const Color secondary = Color(0xFF3D3D3D);
  static const Color tertiary = Color(0xFF6B6B6B);

  // Surface variants
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF000000);
  static const Color surfaceContainerLight = Color(0xFFF5F5F5);
  static const Color surfaceContainerDark = Color(0xFF1A1A1A);

  // --- Geist dark palette ---

  // Backgrounds
  static const Color scaffoldBlack = Color(0xFF000000);
  static const Color cardFill = Color(0xFF1A1A1A);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color containerBorder = Color(0xFF3D3D3D);

  // Navigation
  static const Color navBarFill = Color(0xFF424242);
  static const Color iconInactive = Color(0xFF6B6B6B);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textHint = Color(0x99FFFFFF); // 60% white

  // Interactive states
  static const Color pressedOverlay = Color(0x33FFFFFF); // 20% white
  static const Color focusBorder = Color(0xFFFFFFFF);
  static const Color disabledText = Color(0x66FFFFFF); // 40% white

  // --- Deprecated fitness-specific colors ---
  // These chromatic colors are deprecated and should not be used in default
  // component styling. Use white text with descriptive labels for status
  // indication instead (see Requirement 2.7). Kept for backwards compatibility.

  /// @deprecated Use white text with descriptive labels for success states.
  static const Color successGreen = Color(0xFF4CAF50);

  /// @deprecated Use white text with descriptive labels for rest states.
  static const Color restBlue = Color(0xFF78909C);

  /// @deprecated Use white text with descriptive labels for warning states.
  static const Color warningOrange = Color(0xFFFFA726);

  /// @deprecated Use white text with descriptive labels for error states.
  static const Color errorRed = Color(0xFFD32F2F);

  // Monochrome greys
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Neutral tones
  static const Color onSurfaceLight = Color(0xFF000000);
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFBDBDBD);
}
