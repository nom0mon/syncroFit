import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A widget that draws a simplified grey body silhouette outline and renders
/// white dots at the targeted muscle group locations.
///
/// Used in exercise list rows to visually indicate which muscles an exercise
/// targets.
class BodySilhouetteWidget extends StatelessWidget {
  const BodySilhouetteWidget({
    super.key,
    required this.targetedMuscleGroups,
    this.height = 60,
  });

  /// The muscle groups to highlight with white dots.
  final List<String> targetedMuscleGroups;

  /// The height of the widget in logical pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    // Maintain a 1:2 width-to-height aspect ratio for the body silhouette.
    final width = height * 0.5;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _BodySilhouettePainter(
          targetedMuscleGroups: targetedMuscleGroups,
          outlineColor: AppColors.iconInactive,
          dotColor: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Normalized (x, y) positions for muscle groups within a [0, 1] coordinate
/// space. These map muscle group names to their approximate location on a
/// front-facing human body silhouette.
const Map<String, Offset> muscleGroupPositions = {
  'chest': Offset(0.5, 0.32),
  'back': Offset(0.5, 0.38),
  'shoulders': Offset(0.5, 0.24),
  'biceps': Offset(0.28, 0.38),
  'triceps': Offset(0.72, 0.38),
  'quadriceps': Offset(0.40, 0.62),
  'hamstrings': Offset(0.60, 0.64),
  'glutes': Offset(0.5, 0.52),
  'calves': Offset(0.45, 0.80),
  'abs': Offset(0.5, 0.42),
  'forearms': Offset(0.24, 0.48),
  'traps': Offset(0.5, 0.20),
  'lats': Offset(0.38, 0.36),
};

class _BodySilhouettePainter extends CustomPainter {
  _BodySilhouettePainter({
    required this.targetedMuscleGroups,
    required this.outlineColor,
    required this.dotColor,
  });

  final List<String> targetedMuscleGroups;
  final Color outlineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBodyOutline(canvas, size);
    _drawMuscleDots(canvas, size);
  }

  void _drawBodyOutline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path();

    // Head (oval at top center)
    path.addOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.08),
        width: w * 0.22,
        height: h * 0.10,
      ),
    );

    // Neck
    path.moveTo(w * 0.45, h * 0.13);
    path.lineTo(w * 0.45, h * 0.16);
    path.moveTo(w * 0.55, h * 0.13);
    path.lineTo(w * 0.55, h * 0.16);

    // Torso
    path.moveTo(w * 0.32, h * 0.18);
    path.lineTo(w * 0.30, h * 0.50);
    path.lineTo(w * 0.38, h * 0.52);
    path.lineTo(w * 0.38, h * 0.55);
    path.moveTo(w * 0.68, h * 0.18);
    path.lineTo(w * 0.70, h * 0.50);
    path.lineTo(w * 0.62, h * 0.52);
    path.lineTo(w * 0.62, h * 0.55);

    // Shoulders connection
    path.moveTo(w * 0.32, h * 0.18);
    path.lineTo(w * 0.68, h * 0.18);

    // Left arm
    path.moveTo(w * 0.32, h * 0.18);
    path.lineTo(w * 0.20, h * 0.22);
    path.lineTo(w * 0.15, h * 0.38);
    path.lineTo(w * 0.12, h * 0.50);

    // Right arm
    path.moveTo(w * 0.68, h * 0.18);
    path.lineTo(w * 0.80, h * 0.22);
    path.lineTo(w * 0.85, h * 0.38);
    path.lineTo(w * 0.88, h * 0.50);

    // Left leg
    path.moveTo(w * 0.38, h * 0.55);
    path.lineTo(w * 0.36, h * 0.72);
    path.lineTo(w * 0.34, h * 0.88);
    path.lineTo(w * 0.32, h * 0.95);

    // Right leg
    path.moveTo(w * 0.62, h * 0.55);
    path.lineTo(w * 0.64, h * 0.72);
    path.lineTo(w * 0.66, h * 0.88);
    path.lineTo(w * 0.68, h * 0.95);

    canvas.drawPath(path, paint);
  }

  void _drawMuscleDots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const dotRadius = 2.5;

    for (final group in targetedMuscleGroups) {
      final normalizedKey = group.toLowerCase().trim();
      final position = muscleGroupPositions[normalizedKey];
      if (position != null) {
        final dx = position.dx * size.width;
        final dy = position.dy * size.height;
        canvas.drawCircle(Offset(dx, dy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BodySilhouettePainter oldDelegate) {
    return oldDelegate.targetedMuscleGroups != targetedMuscleGroups ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.dotColor != dotColor;
  }
}
