import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/exercise_library/providers/exercise_provider.dart';
import 'package:synchrofit/features/exercise_library/screens/exercise_and_recommendations_screen.dart';
import 'package:synchrofit/features/exercise_library/screens/exercise_detail_screen.dart';
import 'package:synchrofit/features/exercise_library/widgets/exercise_library_tab.dart';
import 'package:synchrofit/features/exercise_library/widgets/exercise_row.dart';
import 'package:synchrofit/shared/models/enums.dart';
import 'package:synchrofit/shared/models/exercise.dart';

import '../../../support/responsive_test_harness.dart';

void main() {
  group('exercise library responsive layout', () {
    testWidgets('uses a one-column list on a compact phone', (tester) async {
      await tester.pumpResponsiveWidget(
        _withExercises(const ExerciseLibraryTab()),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );

      final rows = find.byType(ExerciseRow);
      expect(rows, findsNWidgets(2));
      expect(
        tester.getTopLeft(rows.at(1)).dy,
        greaterThan(tester.getTopLeft(rows.at(0)).dy),
      );
    });

    testWidgets('uses a two-column grid and wrapped filters on a tablet',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withExercises(const ExerciseLibraryTab()),
        configuration: ResponsiveTestConfiguration.tablet,
        settle: true,
      );

      final rows = find.byType(ExerciseRow);
      expect(rows, findsNWidgets(2));
      expect(
        tester.getTopLeft(rows.at(1)).dy,
        tester.getTopLeft(rows.at(0)).dy,
      );
      expect(
        tester.getTopLeft(rows.at(1)).dx,
        greaterThan(tester.getTopLeft(rows.at(0)).dx),
      );
    });

    testWidgets('keeps search, tabs, filters, and long rows safe at 200% text',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withExercises(const ExerciseAndRecommendationsScreen()),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );

      expect(find.text('Exercise Library'), findsOneWidget);
      expect(find.text('Search exercises...'), findsOneWidget);
      expect(find.byType(ExerciseRow), findsNWidgets(2));
    });
  });

  group('exercise detail responsive layout', () {
    testWidgets('wraps long content and shows truthful 16:9 media fallback',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withExercises(
          const ExerciseDetailScreen(exerciseId: 'long-exercise'),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );

      expect(find.text('No video available'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(
        tester
            .widget<AspectRatio>(find.byKey(const Key('exercise-media')))
            .aspectRatio,
        16 / 9,
      );
      expect(find.text(_longInstruction), findsNWidgets(2));
    });

    testWidgets('places media and detail content side by side on a tablet',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withExercises(
          const ExerciseDetailScreen(exerciseId: 'long-exercise'),
        ),
        configuration: ResponsiveTestConfiguration.tablet,
        settle: true,
      );

      final mediaPosition =
          tester.getTopLeft(find.byKey(const Key('exercise-media')));
      final informationPosition =
          tester.getTopLeft(find.byKey(const Key('exercise-information')));
      expect(informationPosition.dx, greaterThan(mediaPosition.dx));
      expect(informationPosition.dy, mediaPosition.dy);
    });
  });
}

Widget _withExercises(Widget child) {
  return ProviderScope(
    overrides: [
      exerciseProvider.overrideWith(
        (ref) => _ResponsiveExerciseNotifier(ref),
      ),
    ],
    child: Material(child: child),
  );
}

class _ResponsiveExerciseNotifier extends ExerciseNotifier {
  _ResponsiveExerciseNotifier(super.ref) {
    state = const ExerciseState(
      allExercises: _exercises,
      filteredExercises: _exercises,
    );
  }

  @override
  Future<void> loadExercises() async {}
}

const _longInstruction =
    'Keep your torso controlled while moving through the complete range of '
    'motion, then pause briefly before returning to the starting position.';

const _exercises = <Exercise>[
  Exercise(
    id: 'long-exercise',
    name: 'Single-leg resistance-band Romanian deadlift with controlled tempo',
    muscleGroup: 'Posterior chain and hip stabilizers',
    difficulty: DifficultyLevel.intermediate,
    instructions: [_longInstruction, _longInstruction],
    equipment:
        'Long-loop resistance band, stable support, and optional balance pad',
    defaultDurationSeconds: 60,
    defaultSets: 3,
    defaultReps: 10,
    videoPath: 'assets/images/bench_press.png',
  ),
  Exercise(
    id: 'second-exercise',
    name: 'Alternating overhead walking lunge with rotation',
    muscleGroup: 'Quadriceps and shoulders',
    difficulty: DifficultyLevel.advanced,
    instructions: [_longInstruction],
    equipment: 'Dumbbells',
    defaultDurationSeconds: 90,
    defaultSets: 4,
    defaultReps: 12,
  ),
];
