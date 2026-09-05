import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/exercise_library/providers/exercise_provider.dart';
import 'package:synchrofit/features/workout/providers/timer_controller.dart';
import 'package:synchrofit/features/workout/providers/workout_generator_provider.dart';
import 'package:synchrofit/features/workout/providers/workout_provider.dart';
import 'package:synchrofit/features/workout/screens/rest_timer_screen.dart';
import 'package:synchrofit/features/workout/screens/workout_active_screen.dart';
import 'package:synchrofit/features/workout/screens/workout_generator_screen.dart';
import 'package:synchrofit/shared/models/models.dart';

import '../../../support/responsive_test_harness.dart';

void main() {
  group('WorkoutGeneratorScreen responsive layout', () {
    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets(
        'keeps generated content and the primary action usable at ${configuration.name}',
        (tester) async {
          await tester.pumpResponsiveWidget(
            _generatorScreen(),
            configuration: configuration,
            settle: true,
            mustRemainVisible: [
              find.byKey(const Key('generate-workout-action')),
            ],
          );

          expect(find.text(_exercises.first.name), findsOneWidget);
          expect(find.text('Regenerate Workout'), findsOneWidget);
        },
      );
    }

    testWidgets('long generated content scrolls while completion stays visible',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _generatorScreen(),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
        mustRemainVisible: [
          find.byKey(const Key('generate-workout-action')),
        ],
      );

      final lastExercise = find.text(_exercises.last.name);
      await tester.scrollUntilVisible(
        lastExercise,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('workout-generator-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();

      expect(lastExercise, findsOneWidget);
      tester.expectFullyVisible(
        find.byKey(const Key('generate-workout-action')),
        configuration: ResponsiveTestConfiguration.compactPhone,
      );
    });

    testWidgets('selection sheet remains height and keyboard safe',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _generatorScreen(),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );

      await tester.tap(find.text('Preferred (0)'));
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();

      expect(find.text('Preferred Exercises'), findsOneWidget);
      tester.expectFullyVisible(
        find.text('Done'),
        configuration: ResponsiveTestConfiguration.compactPhone,
      );
    });
  });

  group('WorkoutActiveScreen responsive layout', () {
    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets(
        'keeps set controls visible at ${configuration.name}',
        (tester) async {
          await tester.pumpResponsiveWidget(
            _activeWorkoutScreen(),
            configuration: configuration,
            settle: true,
            mustRemainVisible: [
              find.byKey(const Key('finish-set-action')),
              find.byKey(const Key('skip-exercise-action')),
            ],
          );

          expect(find.text(_exercises.first.name), findsOneWidget);
          expect(find.text('48 reps'), findsOneWidget);
        },
      );
    }

    testWidgets('long instructions scroll independently of active controls',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _activeWorkoutScreen(),
        configuration: ResponsiveTestConfiguration.landscape,
        settle: true,
        mustRemainVisible: [
          find.byKey(const Key('finish-set-action')),
        ],
      );

      final finalInstruction = find.text(_longInstructions.last);
      await tester.scrollUntilVisible(
        finalInstruction,
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('active-workout-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();

      expect(finalInstruction, findsOneWidget);
      tester.expectFullyVisible(
        find.byKey(const Key('finish-set-action')),
        configuration: ResponsiveTestConfiguration.landscape,
      );
    });

    testWidgets('active controls stay above gesture navigation inset',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withBottomInset(_activeWorkoutScreen(), 32),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
        mustRemainVisible: [
          find.byKey(const Key('finish-set-action')),
          find.byKey(const Key('skip-exercise-action')),
        ],
      );
    });
  });

  group('RestTimerScreen responsive layout', () {
    for (final configuration in [
      ResponsiveTestConfiguration.compactPhone,
      ResponsiveTestConfiguration.landscape,
      ResponsiveTestConfiguration.largeText,
    ]) {
      testWidgets(
        'keeps timer, next exercise, and skip action usable at ${configuration.name}',
        (tester) async {
          await tester.pumpResponsiveWidget(
            _restTimerScreen(),
            configuration: configuration,
            settle: true,
            mustRemainVisible: [
              find.byKey(const Key('skip-rest-action')),
            ],
          );

          expect(find.text('02:00'), findsOneWidget);
          expect(find.text('Set 2 of 24'), findsOneWidget);
        },
      );
    }

    testWidgets('skip rest action stays above gesture navigation inset',
        (tester) async {
      await tester.pumpResponsiveWidget(
        _withBottomInset(_restTimerScreen(), 32),
        configuration: ResponsiveTestConfiguration.landscape,
        settle: true,
        mustRemainVisible: [
          find.byKey(const Key('skip-rest-action')),
        ],
      );
    });
  });
}

Widget _generatorScreen() {
  const state = WorkoutGeneratorState(
    status: WorkoutGeneratorStatus.generated,
    generatedWorkouts: _generatedWorkouts,
  );

  return ProviderScope(
    overrides: [
      workoutGeneratorProvider.overrideWith(
        (ref) => _FakeWorkoutGeneratorNotifier(ref, state),
      ),
      exerciseProvider.overrideWith(
        (ref) => _FakeExerciseNotifier(ref, _exercises),
      ),
    ],
    child: const WorkoutGeneratorScreen(),
  );
}

Widget _activeWorkoutScreen() {
  return ProviderScope(
    overrides: [
      workoutProvider.overrideWith(
        (ref) => _FakeWorkoutNotifier(
          ref,
          const WorkoutSessionState(
            workout: _activeWorkout,
            currentSet: 12,
            isInProgress: true,
          ),
        ),
      ),
      exerciseProvider.overrideWith(
        (ref) => _FakeExerciseNotifier(ref, _exercises),
      ),
    ],
    child: const WorkoutActiveScreen(workoutId: 'active-workout'),
  );
}

Widget _restTimerScreen() {
  return ProviderScope(
    overrides: [
      workoutProvider.overrideWith(
        (ref) => _FakeWorkoutNotifier(
          ref,
          const WorkoutSessionState(
            workout: _activeWorkout,
            isInProgress: true,
            isResting: true,
          ),
        ),
      ),
      exerciseProvider.overrideWith(
        (ref) => _FakeExerciseNotifier(ref, _exercises),
      ),
      restTimerControllerProvider.overrideWith(
        (ref) => _FakeTimerController(),
      ),
    ],
    child: const RestTimerScreen(workoutId: 'active-workout'),
  );
}

Widget _withBottomInset(Widget child, double bottomInset) {
  return Builder(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(bottom: bottomInset),
          viewPadding: mediaQuery.viewPadding.copyWith(bottom: bottomInset),
        ),
        child: child,
      );
    },
  );
}

class _FakeWorkoutGeneratorNotifier extends WorkoutGeneratorNotifier {
  _FakeWorkoutGeneratorNotifier(super.ref, WorkoutGeneratorState initialState) {
    state = initialState;
  }
}

class _FakeWorkoutNotifier extends WorkoutNotifier {
  _FakeWorkoutNotifier(super.ref, WorkoutSessionState initialState) {
    state = initialState;
  }
}

class _FakeExerciseNotifier extends ExerciseNotifier {
  _FakeExerciseNotifier(super.ref, List<Exercise> exercises) {
    state = ExerciseState(
      allExercises: exercises,
      filteredExercises: exercises,
    );
  }

  @override
  Future<void> loadExercises() async {}
}

class _FakeTimerController extends TimerController {
  @override
  void start(int durationSeconds) {
    state = TimerControllerState(
      remainingSeconds: durationSeconds,
      state: TimerState.running,
    );
  }
}

const _longInstructions = [
  'Brace your core and keep a stable neutral spine throughout the movement.',
  'Lower the weight slowly while maintaining control through the full range.',
  'Pause briefly at the hardest point without relaxing your working muscles.',
  'Drive through the movement and avoid using momentum to finish the repetition.',
  'Reset your position and breathing before beginning the next repetition.',
  'Continue with deliberate technique even as the set becomes challenging.',
];

final _exercises = List<Exercise>.generate(
  16,
  (index) => Exercise(
    id: '${index + 1}',
    name: index == 0
        ? 'Single Arm Cross Body Resistance Band Bulgarian Split Squat'
        : index == 1
            ? 'Alternating Kneeling Overhead Press With Controlled Rotation'
            : 'Generated exercise ${index + 1} with an intentionally descriptive name',
    muscleGroup: 'Full body muscle group with a long translated label',
    difficulty: DifficultyLevel.intermediate,
    instructions: index == 0 ? _longInstructions : const ['Move with control.'],
    defaultDurationSeconds: 0,
    defaultSets: 12,
    defaultReps: 48,
  ),
);

const _generatedWorkouts = [
  Workout(
    id: 'generated-1',
    name: 'Comprehensive full body strength and stability session',
    dayOfWeek: 'Monday',
    estimatedDurationMinutes: 120,
    isGenerated: true,
    exercises: [
      WorkoutExercise(
        exerciseId: 1,
        sets: 12,
        reps: 48,
        durationSeconds: 0,
        order: 1,
      ),
      WorkoutExercise(
        exerciseId: 2,
        sets: 4,
        reps: 0,
        durationSeconds: 120,
        order: 2,
      ),
      WorkoutExercise(
          exerciseId: 3, sets: 3, reps: 12, durationSeconds: 0, order: 3),
      WorkoutExercise(
          exerciseId: 4, sets: 3, reps: 12, durationSeconds: 0, order: 4),
      WorkoutExercise(
          exerciseId: 5, sets: 3, reps: 12, durationSeconds: 0, order: 5),
      WorkoutExercise(
          exerciseId: 6, sets: 3, reps: 12, durationSeconds: 0, order: 6),
      WorkoutExercise(
          exerciseId: 7, sets: 3, reps: 12, durationSeconds: 0, order: 7),
      WorkoutExercise(
          exerciseId: 8, sets: 3, reps: 12, durationSeconds: 0, order: 8),
    ],
  ),
  Workout(
    id: 'generated-2',
    name: 'Long generated endurance and mobility workout',
    dayOfWeek: 'Thursday',
    estimatedDurationMinutes: 90,
    isGenerated: true,
    exercises: [
      WorkoutExercise(
          exerciseId: 9, sets: 3, reps: 12, durationSeconds: 0, order: 1),
      WorkoutExercise(
          exerciseId: 10, sets: 3, reps: 12, durationSeconds: 0, order: 2),
      WorkoutExercise(
          exerciseId: 11, sets: 3, reps: 12, durationSeconds: 0, order: 3),
      WorkoutExercise(
          exerciseId: 12, sets: 3, reps: 12, durationSeconds: 0, order: 4),
      WorkoutExercise(
          exerciseId: 13, sets: 3, reps: 12, durationSeconds: 0, order: 5),
      WorkoutExercise(
          exerciseId: 14, sets: 3, reps: 12, durationSeconds: 0, order: 6),
      WorkoutExercise(
          exerciseId: 15, sets: 3, reps: 12, durationSeconds: 0, order: 7),
      WorkoutExercise(
          exerciseId: 16, sets: 3, reps: 12, durationSeconds: 0, order: 8),
    ],
  ),
];

const _activeWorkout = Workout(
  id: 'active-workout',
  name: 'Active workout',
  estimatedDurationMinutes: 60,
  exercises: [
    WorkoutExercise(
      exerciseId: 1,
      sets: 24,
      reps: 48,
      durationSeconds: 0,
      order: 1,
    ),
    WorkoutExercise(
      exerciseId: 2,
      sets: 8,
      reps: 0,
      durationSeconds: 120,
      order: 2,
    ),
  ],
);
