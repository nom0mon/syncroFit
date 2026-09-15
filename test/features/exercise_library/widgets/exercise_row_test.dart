import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:synchrofit/core/theme/app_colors.dart';
import 'package:synchrofit/features/exercise_library/widgets/exercise_row.dart';
import 'package:synchrofit/shared/models/enums.dart';
import 'package:synchrofit/shared/models/exercise.dart';
import 'package:synchrofit/shared/widgets/exercise_illustration.dart';

void main() {
  setUpAll(() {
    // Prevent google_fonts from making HTTP requests in tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const testExercise = Exercise(
    id: 'ex-001',
    name: 'Bench Press',
    muscleGroup: 'Chest',
    difficulty: DifficultyLevel.intermediate,
    instructions: ['Lie on bench', 'Lower bar to chest', 'Press up'],
    equipment: 'Barbell',
    defaultDurationSeconds: 300,
    defaultSets: 4,
    defaultReps: 10,
    videoPath: 'assets/images/bench_press.png',
  );

  const testExerciseNoEquipment = Exercise(
    id: 'ex-002',
    name: 'Push Up',
    muscleGroup: 'Chest',
    difficulty: DifficultyLevel.beginner,
    instructions: ['Get in plank position', 'Lower body', 'Push up'],
    equipment: null,
    defaultDurationSeconds: 180,
    defaultSets: 3,
    defaultReps: 15,
    videoPath: 'assets/images/push_up.png',
  );

  Widget buildSubject({
    Exercise exercise = testExercise,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ExerciseRow(
          exercise: exercise,
          onTap: onTap,
        ),
      ),
    );
  }

  group('ExerciseRow', () {
    test('all SyncroFit catalog exercises have illustration mappings', () {
      const names = [
        'Push-Up', 'Dumbbell Bench Press', 'Barbell Bench Press',
        'Cable Chest Fly', 'Pull-Up', 'Barbell Bent-Over Row',
        'Dumbbell Single-Arm Row', 'Resistance Band Pull-Apart',
        'Dumbbell Overhead Press', 'Pike Push-Up', 'Kettlebell Press',
        'Dumbbell Bicep Curl', 'Barbell Curl', 'Chin-Up',
        'Resistance Band Curl', 'Tricep Dip',
        'Dumbbell Overhead Tricep Extension', 'Cable Tricep Pushdown',
        'Bodyweight Squat', 'Barbell Back Squat', 'Kettlebell Goblet Squat',
        'Leg Press', 'Dumbbell Romanian Deadlift', 'Plank',
        'Hanging Leg Raise', 'Kettlebell Russian Twist', 'Cable Woodchop',
        'Burpee', 'Kettlebell Swing', 'Barbell Deadlift',
        'Resistance Band Thruster', 'Dumbbell Clean and Press',
        'Resistance Band Lateral Raise', 'Close-Grip Barbell Bench Press',
        'Walking Lunge', 'Mountain Climber', 'Jumping Jack', 'High Knees',
        'Broad Jump',
      ];

      expect(
        names.where(
          (name) => !ExerciseIllustration.hasIllustrationForName(name),
        ),
        isEmpty,
      );
    });

    testWidgets('displays exercise name text', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Bench Press'), findsOneWidget);
    });

    testWidgets(
        'displays subtitle as "{muscleGroup} · {equipment}" when equipment is present',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Chest · Barbell'), findsOneWidget);
    });

    testWidgets('displays subtitle as just muscleGroup when equipment is null',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(exercise: testExerciseNoEquipment),
      );

      expect(find.text('Target: Chest'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('displays subtitle as just muscleGroup when equipment is empty',
        (tester) async {
      const exerciseEmptyEquipment = Exercise(
        id: 'ex-003',
        name: 'Plank',
        muscleGroup: 'Abs',
        difficulty: DifficultyLevel.beginner,
        instructions: ['Hold plank position'],
        equipment: '',
        defaultDurationSeconds: 60,
        defaultSets: 3,
        defaultReps: 1,
        videoPath: 'assets/images/plank.png',
      );

      await tester.pumpWidget(
        buildSubject(exercise: exerciseEmptyEquipment),
      );

      expect(find.text('Target: Abs'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('subtitle uses AppColors.textSecondary color', (tester) async {
      await tester.pumpWidget(buildSubject());

      final subtitleFinder = find.text('Chest · Barbell');
      final subtitleWidget = tester.widget<Text>(subtitleFinder);
      expect(subtitleWidget.style?.color, AppColors.textSecondary);
    });

    testWidgets('contains a movement illustration', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(ExerciseIllustration), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(onTap: () => tapped = true),
      );

      await tester.tap(find.byType(ExerciseRow));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders bottom border with AppColors.cardBorder',
        (tester) async {
      await tester.pumpWidget(buildSubject());

      final containerFinder = find.descendant(
        of: find.byType(ExerciseRow),
        matching: find.byType(Container),
      );

      // Find the Container that has the BoxDecoration with border
      Container? borderContainer;
      for (final element in containerFinder.evaluate()) {
        final widget = element.widget as Container;
        final decoration = widget.decoration;
        if (decoration is BoxDecoration && decoration.border != null) {
          borderContainer = widget;
          break;
        }
      }

      expect(borderContainer, isNotNull);
      final decoration = borderContainer!.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.bottom.color, AppColors.cardBorder);
      expect(border.bottom.width, 0.5);
    });
  });
}
