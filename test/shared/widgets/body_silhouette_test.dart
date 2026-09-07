import 'package:glados/glados.dart';
import 'package:synchrofit/shared/widgets/body_silhouette_widget.dart';

/// **Validates: Requirements 3.4**
///
/// Property 9: Muscle group positions are within body outline bounds
///
/// For any valid muscle group name from the supported set, the mapped dot
/// position (x, y) SHALL fall within the body silhouette bounding box
/// (0 ≤ x ≤ 1, 0 ≤ y ≤ 1), ensuring no dots render outside the outline.
///
/// Since positions are normalized to [0, 1], both dx and dy must satisfy
/// 0 <= value <= 1.
void main() {
  final supportedMuscleGroups = muscleGroupPositions.keys.toList();

  group('Property 9: Muscle group positions are within body outline bounds',
      () {
    test('all muscle group positions have dx in [0, 1] and dy in [0, 1]', () {
      for (final entry in muscleGroupPositions.entries) {
        final name = entry.key;
        final position = entry.value;

        expect(
          position.dx,
          greaterThanOrEqualTo(0.0),
          reason: '$name position dx (${position.dx}) should be >= 0',
        );
        expect(
          position.dx,
          lessThanOrEqualTo(1.0),
          reason: '$name position dx (${position.dx}) should be <= 1',
        );
        expect(
          position.dy,
          greaterThanOrEqualTo(0.0),
          reason: '$name position dy (${position.dy}) should be >= 0',
        );
        expect(
          position.dy,
          lessThanOrEqualTo(1.0),
          reason: '$name position dy (${position.dy}) should be <= 1',
        );
      }
    });

    Glados(any.intInRange(0, supportedMuscleGroups.length - 1)).test(
      'randomly selected muscle group has position within [0, 1] bounds',
      (index) {
        final muscleGroup = supportedMuscleGroups[index];
        final position = muscleGroupPositions[muscleGroup]!;

        expect(
          position.dx >= 0.0 && position.dx <= 1.0,
          isTrue,
          reason: '$muscleGroup dx=${position.dx} is outside [0, 1] bounds',
        );
        expect(
          position.dy >= 0.0 && position.dy <= 1.0,
          isTrue,
          reason: '$muscleGroup dy=${position.dy} is outside [0, 1] bounds',
        );
      },
    );
  });
}
