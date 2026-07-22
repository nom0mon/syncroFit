import 'package:flutter/material.dart';

/// A non-interactive linear gradient overlay for scrollable content edges.
///
/// Positioned at the top or bottom of a scrollable area, it provides a smooth
/// visual fade from the scaffold background into content (or vice-versa).
///
/// Wrapped in [IgnorePointer] so it never intercepts touch events.
class EdgeFadeGradient extends StatelessWidget {
  const EdgeFadeGradient({
    super.key,
    required this.isTop,
    this.height = 32,
  });

  /// When `true`, the gradient fades from [scaffoldBackgroundColor] at the top
  /// to transparent at the bottom. When `false`, it fades from transparent at
  /// the top to [scaffoldBackgroundColor] at the bottom.
  final bool isTop;

  /// The height of the gradient overlay in logical pixels (24–48dp).
  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    // In light mode the fade overlay obscures content (white band over white
    // background adds no value and hides text/charts). Only render in dark mode.
    if (brightness == Brightness.light) {
      return const SizedBox.shrink();
    }

    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final colors = isTop
        ? [scaffoldColor, Colors.transparent]
        : [Colors.transparent, scaffoldColor];

    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
      ),
    );
  }
}
