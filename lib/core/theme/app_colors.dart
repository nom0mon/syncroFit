import 'package:flutter/material.dart';

/// Named color constants for the SyncroFit palette.
///
/// Brand palette:
/// - Navy  `#142D4E` — primary dark surface / scaffold base
/// - Blue  `#3478F6` — primary interactive (buttons, selected, focus)
/// - Lime  `#C6F135` — accent / highlight (secondary emphasis)
///
/// Light screens use white surfaces with navy text and blue interactive
/// elements. Dark screens use the navy scaffold with white text, blue
/// primary actions, and a lime accent.
abstract final class AppColors {
  // --- Brand palette ---
  static const Color brandNavy = Color(0xFF142D4E);
  static const Color brandBlue = Color(0xFF3478F6);
  static const Color brandLime = Color(0xFFC6F135);

  // Navy shades (derived) for layered surfaces on the dark theme.
  static const Color navyDeep = Color(0xFF0E2038); // darker scaffold base
  static const Color navySurface = Color(0xFF142D4E); // primary navy
  static const Color navyCard = Color(0xFF1B3A63); // raised card fill
  static const Color navyBorder = Color(0xFF2C4C7C); // card/container border

  // Blue shades for interactive emphasis and pressed states.
  static const Color blue = Color(0xFF3478F6);
  static const Color blueDark = Color(0xFF2A60C4);

  // Primary palette (brand-aligned)
  static const Color primary = Color(0xFF3478F6); // blue — primary interactive
  static const Color secondary = Color(0xFF142D4E); // navy
  static const Color tertiary = Color(0xFFC6F135); // lime accent

  // Surface variants
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0E2038);
  static const Color surfaceContainerLight = Color(0xFFF2F5FA);
  static const Color surfaceContainerDark = Color(0xFF1B3A63);

  // --- Dark palette (navy) ---

  // Backgrounds
  static const Color scaffoldBlack = Color(0xFF0E2038); // navy scaffold base
  static const Color cardFill = Color(0xFF1B3A63);
  static const Color cardBorder = Color(0xFF2C4C7C);
  static const Color containerBorder = Color(0xFF2C4C7C);

  // Navigation
  static const Color navBarFill = Color(0xFF142D4E);
  static const Color iconInactive = Color(0x99FFFFFF); // 60% white

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textHint = Color(0x99FFFFFF); // 60% white

  // Interactive states
  static const Color pressedOverlay = Color(0x333478F6); // 20% brand blue
  static const Color focusBorder = Color(0xFF3478F6); // brand blue focus
  static const Color disabledText = Color(0x66FFFFFF); // 40% white

  // Accent (lime) — reserved for highlights, selected emphasis, progress.
  static const Color accent = Color(0xFFC6F135);
  static const Color onAccent = Color(0xFF142D4E); // navy text on lime

  // --- Status colors ---
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color restBlue = Color(0xFF3478F6);
  static const Color warningOrange = Color(0xFFFFA726);
  static const Color errorRed = Color(0xFFD32F2F);

  // Neutral greys
  static const Color grey100 = Color(0xFFF2F5FA);
  static const Color grey200 = Color(0xFFE6EBF2);
  static const Color grey300 = Color(0xFFD5DEEA);
  static const Color grey400 = Color(0xFFB4C0D4);
  static const Color grey500 = Color(0xFF8A98B0);
  static const Color grey600 = Color(0xFF657186);
  static const Color grey700 = Color(0xFF49536A);
  static const Color grey800 = Color(0xFF2C3A52);
  static const Color grey900 = Color(0xFF142D4E); // navy — primary dark

  // Neutral tones
  static const Color onSurfaceLight = Color(0xFF142D4E); // navy text on light
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFB4C0D4);
}
