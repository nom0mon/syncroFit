import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/widgets/exercise_media.dart';

void main() {
  group('hasPlayableExerciseVideo', () {
    test('returns false for null, empty, and whitespace paths', () {
      expect(hasPlayableExerciseVideo(null), isFalse);
      expect(hasPlayableExerciseVideo(''), isFalse);
      expect(hasPlayableExerciseVideo('   '), isFalse);
    });

    test('returns false for image placeholder assets', () {
      expect(hasPlayableExerciseVideo('assets/images/push_up.png'), isFalse);
      expect(hasPlayableExerciseVideo('bench_press.png'), isFalse);
      expect(
        hasPlayableExerciseVideo('https://example.com/pushup.png'),
        isFalse,
      );
    });

    test('returns false for paths without an extension', () {
      expect(hasPlayableExerciseVideo('assets/videos/plank'), isFalse);
      expect(hasPlayableExerciseVideo('https://example.com/video'), isFalse);
    });

    test('returns false for unsupported or non-network URI schemes', () {
      expect(hasPlayableExerciseVideo('ftp://example.com/clip.mp4'), isFalse);
      expect(hasPlayableExerciseVideo('file:///tmp/clip.mp4'), isFalse);
    });

    test('returns true for supported local video assets', () {
      expect(hasPlayableExerciseVideo('assets/videos/plank.mp4'), isTrue);
      expect(hasPlayableExerciseVideo('squat.webm'), isTrue);
      expect(hasPlayableExerciseVideo('lunges.MKV'), isTrue);
    });

    test('returns true for supported network video URLs', () {
      expect(
        hasPlayableExerciseVideo('https://example.com/media/plank.mp4'),
        isTrue,
      );
      expect(
        hasPlayableExerciseVideo('http://cdn.example.com/a/b/clip.m4v'),
        isTrue,
      );
    });
  });

  group('ExerciseMedia widget', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 360, child: child),
          ),
        );

    testWidgets('shows neutral unavailable state when no playable video',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMedia(
            videoPath: 'assets/images/push_up.png',
            exerciseName: 'Push Up',
          ),
        ),
      );

      expect(find.text('No video available'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(
        tester.widget<AspectRatio>(find.byKey(const Key('exercise-media'))).aspectRatio,
        16 / 9,
      );
    });

    testWidgets('shows a play affordance when a playable video exists',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMedia(
            videoPath: 'assets/videos/plank.mp4',
            exerciseName: 'Plank',
          ),
        ),
      );

      expect(find.text('Play video guide'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_outlined), findsNothing);
    });

    testWidgets('exposes an accessible semantics label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ExerciseMedia(
            videoPath: null,
            exerciseName: 'Bench Press',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('No video available for Bench Press'),
        findsOneWidget,
      );
    });
  });
}
