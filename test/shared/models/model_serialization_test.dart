import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/models/user.dart';
import 'package:synchrofit/shared/models/user_profile.dart';
import 'package:synchrofit/shared/models/exercise.dart';
import 'package:synchrofit/shared/models/workout.dart';
import 'package:synchrofit/shared/models/workout_exercise.dart';
import 'package:synchrofit/shared/models/workout_session.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';
import 'package:synchrofit/shared/models/progress_record.dart';
import 'package:synchrofit/shared/models/notification_item.dart';
import 'package:synchrofit/shared/models/enums.dart';

void main() {
  group('User serialization', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 1,
        'name': 'John Doe',
        'email': 'john@example.com',
        'created_at': '2024-01-15T10:30:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, '1');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.createdAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
    });

    test('toJson produces correct output', () {
      final user = User(
        id: '1',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );

      final json = user.toJson();

      expect(json['id'], '1');
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['created_at'], '2024-01-15T10:30:00.000Z');
    });
  });

  group('UserProfile serialization', () {
    test('fromJson parses correctly with enum mappings', () {
      final json = {
        'user_id': 42,
        'name': 'Jane',
        'age': 28,
        'height_cm': 165.5,
        'weight_kg': 60.0,
        'gender': 'female',
        'fitness_goal': 'lose_weight',
        'fitness_level': 'intermediate',
        'workout_preference': 'gym',
        'availability_days': ['monday', 'wednesday', 'friday'],
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.userId, '42');
      expect(profile.name, 'Jane');
      expect(profile.age, 28);
      expect(profile.heightCm, 165.5);
      expect(profile.weightKg, 60.0);
      expect(profile.gender, Gender.female);
      expect(profile.fitnessGoal, FitnessGoal.loseWeight);
      expect(profile.fitnessLevel, FitnessLevel.intermediate);
      expect(profile.workoutPreference, WorkoutPreference.gym);
      expect(profile.workoutAvailability, [
        DayOfWeek.monday,
        DayOfWeek.wednesday,
        DayOfWeek.friday,
      ]);
    });

    test('toJson maps enums to backend values', () {
      final profile = UserProfile(
        userId: '1',
        name: 'Jane',
        age: 28,
        heightCm: 165.5,
        weightKg: 60.0,
        gender: Gender.female,
        fitnessGoal: FitnessGoal.buildMuscle,
        fitnessLevel: FitnessLevel.advanced,
        workoutPreference: WorkoutPreference.outdoor,
        workoutAvailability: [DayOfWeek.tuesday, DayOfWeek.saturday],
      );

      final json = profile.toJson();

      expect(json['user_id'], '1');
      expect(json['gender'], 'female');
      expect(json['goal'], 'build_muscle');
      expect(json['fitness_level'], 'advanced');
      expect(json['workout_preference'], 'outdoor');
      expect(json['availability_days'], ['tuesday', 'saturday']);
    });

    test('fromJson handles all fitness goals', () {
      final base = {
        'user_id': 1,
        'name': 'Test',
        'age': 25,
        'height_cm': 170,
        'weight_kg': 70,
        'gender': 'male',
        'fitness_level': 'beginner',
        'workout_preference': 'home',
        'availability_days': ['monday'],
      };

      // Uses 'goal' key (backend format)
      expect(
        UserProfile.fromJson({...base, 'goal': 'stay_fit'}).fitnessGoal,
        FitnessGoal.maintainFitness,
      );
      expect(
        UserProfile.fromJson({...base, 'goal': 'increase_stamina'}).fitnessGoal,
        FitnessGoal.improveEndurance,
      );
      // Falls back to 'fitness_goal' key (legacy/local cache format)
      expect(
        UserProfile.fromJson({...base, 'fitness_goal': 'lose_weight'})
            .fitnessGoal,
        FitnessGoal.loseWeight,
      );
    });

    test('fromJson handles missing name gracefully', () {
      final json = {
        'user_id': 1,
        'age': 25,
        'height_cm': 170,
        'weight_kg': 70,
        'gender': 'male',
        'goal': 'stay_fit',
        'fitness_level': 'beginner',
        'workout_preference': 'home',
        'availability_days': ['monday'],
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.name, '');
    });

    test('toApiJson excludes user_id, name, and updated_at', () {
      final profile = UserProfile(
        userId: '1',
        name: 'Jane',
        age: 28,
        heightCm: 165.5,
        weightKg: 60.0,
        gender: Gender.female,
        fitnessGoal: FitnessGoal.buildMuscle,
        fitnessLevel: FitnessLevel.advanced,
        workoutPreference: WorkoutPreference.outdoor,
        workoutAvailability: [DayOfWeek.tuesday, DayOfWeek.saturday],
        updatedAt: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );

      final json = profile.toApiJson();

      expect(json.containsKey('user_id'), false);
      expect(json.containsKey('name'), false);
      expect(json.containsKey('updated_at'), false);
      expect(json['age'], 28);
      expect(json['goal'], 'build_muscle');
      expect(json['gender'], 'female');
      expect(json['fitness_level'], 'advanced');
      expect(json['workout_preference'], 'outdoor');
      expect(json['availability_days'], ['tuesday', 'saturday']);
    });
  });

  group('Exercise serialization', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 5,
        'name': 'Push-ups',
        'muscle_group': 'chest',
        'difficulty': 'beginner',
        'instructions': ['Get in plank position', 'Lower body', 'Push up'],
        'equipment': 'none',
        'default_duration_seconds': 60,
        'default_sets': 3,
        'default_reps': 12,
        'image_url': 'https://example.com/pushup.png',
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.id, '5');
      expect(exercise.name, 'Push-ups');
      expect(exercise.muscleGroup, 'chest');
      expect(exercise.difficulty, DifficultyLevel.beginner);
      expect(exercise.instructions.length, 3);
      expect(exercise.equipment, 'none');
      expect(exercise.defaultDurationSeconds, 60);
      expect(exercise.defaultSets, 3);
      expect(exercise.defaultReps, 12);
      expect(exercise.imagePlaceholder, 'https://example.com/pushup.png');
    });

    test('fromJson handles null equipment and image_url', () {
      final json = {
        'id': 1,
        'name': 'Squats',
        'muscle_group': 'legs',
        'difficulty': 'intermediate',
        'instructions': ['Stand', 'Squat'],
        'equipment': null,
        'default_duration_seconds': 45,
        'default_sets': 4,
        'default_reps': 10,
        'image_url': null,
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.equipment, null);
      expect(exercise.imagePlaceholder, '');
    });
  });

  group('Workout serialization', () {
    test('fromJson parses nested exercises', () {
      final json = {
        'id': 10,
        'name': 'Morning Workout',
        'estimated_duration_minutes': 45,
        'exercises': [
          {
            'exercise_id': 1,
            'exercise_name': 'Push-ups',
            'sets': 3,
            'reps': 12,
            'duration_seconds': 60,
            'rest_seconds': 30,
            'image_url': 'img.png',
          },
          {
            'exercise_id': 2,
            'exercise_name': 'Squats',
            'sets': 4,
            'reps': 10,
            'duration_seconds': 45,
            'rest_seconds': 45,
            'image_url': 'img2.png',
          },
        ],
      };

      final workout = Workout.fromJson(json);

      expect(workout.id, '10');
      expect(workout.name, 'Morning Workout');
      expect(workout.estimatedDurationMinutes, 45);
      expect(workout.exercises.length, 2);
      expect(workout.exercises[0].exerciseName, 'Push-ups');
      expect(workout.exercises[1].sets, 4);
    });

    test('toJson serializes nested exercises', () {
      final workout = Workout(
        id: '1',
        name: 'Test',
        estimatedDurationMinutes: 30,
        exercises: [
          WorkoutExercise(
            exerciseId: '1',
            exerciseName: 'Ex1',
            sets: 3,
            reps: 10,
            durationSeconds: 60,
            restSeconds: 30,
            thumbnailPlaceholder: 'img.png',
          ),
        ],
      );

      final json = workout.toJson();

      expect(json['estimated_duration_minutes'], 30);
      expect((json['exercises'] as List).length, 1);
      expect(
        (json['exercises'] as List)[0]['exercise_name'],
        'Ex1',
      );
    });
  });

  group('WorkoutSession serialization', () {
    test('fromJson parses nested completed exercises', () {
      final json = {
        'id': 100,
        'workout_id': 10,
        'workout_name': 'Leg Day',
        'completed_at': '2024-03-20T14:30:00.000Z',
        'total_duration_seconds': 2700,
        'exercises_completed': 5,
        'exercises': [
          {
            'exercise_id': 1,
            'exercise_name': 'Squats',
            'sets_completed': 3,
            'reps_or_duration': 12,
          },
        ],
      };

      final session = WorkoutSession.fromJson(json);

      expect(session.id, '100');
      expect(session.workoutId, '10');
      expect(session.workoutName, 'Leg Day');
      expect(session.totalDurationSeconds, 2700);
      expect(session.exercisesCompleted, 5);
      expect(session.exercises.length, 1);
      expect(session.exercises[0].setsCompleted, 3);
    });
  });

  group('ProgressRecord serialization', () {
    test('fromJson parses recorded_at to date', () {
      final json = {
        'id': 7,
        'recorded_at': '2024-02-10T00:00:00.000Z',
        'weight_kg': 72.5,
        'bmi': 23.8,
        'workouts_completed': 12,
      };

      final record = ProgressRecord.fromJson(json);

      expect(record.id, '7');
      expect(record.date, DateTime.parse('2024-02-10T00:00:00.000Z'));
      expect(record.weightKg, 72.5);
      expect(record.bmi, 23.8);
      expect(record.workoutsCompleted, 12);
    });

    test('toJson outputs recorded_at', () {
      final record = ProgressRecord(
        id: '1',
        date: DateTime.parse('2024-02-10T00:00:00.000Z'),
        weightKg: 72.5,
        bmi: 23.8,
        workoutsCompleted: 5,
      );

      final json = record.toJson();

      expect(json['recorded_at'], '2024-02-10T00:00:00.000Z');
      expect(json['weight_kg'], 72.5);
    });
  });

  group('NotificationItem serialization', () {
    test('fromJson parses notification type correctly', () {
      final json = {
        'id': 3,
        'title': 'Workout Time!',
        'description': 'Your morning workout starts in 15 minutes',
        'timestamp': '2024-03-20T07:45:00.000Z',
        'type': 'workout_reminder',
        'is_read': false,
      };

      final notification = NotificationItem.fromJson(json);

      expect(notification.id, '3');
      expect(notification.title, 'Workout Time!');
      expect(notification.type, NotificationType.workoutReminder);
      expect(notification.isRead, false);
    });

    test('toJson maps notification type to snake_case', () {
      final notification = NotificationItem(
        id: '1',
        title: 'Achievement',
        description: 'You earned a badge',
        timestamp: DateTime.parse('2024-03-20T07:45:00.000Z'),
        type: NotificationType.communityInteraction,
        isRead: true,
      );

      final json = notification.toJson();

      expect(json['type'], 'community_interaction');
      expect(json['is_read'], true);
    });
  });

  group('CompletedExercise serialization', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'exercise_id': 5,
        'exercise_name': 'Deadlift',
        'sets_completed': 4,
        'reps_or_duration': 8,
      };

      final exercise = CompletedExercise.fromJson(json);
      final outputJson = exercise.toJson();

      expect(outputJson['exercise_id'], '5');
      expect(outputJson['exercise_name'], 'Deadlift');
      expect(outputJson['sets_completed'], 4);
      expect(outputJson['reps_or_duration'], 8);
    });
  });

  group('WorkoutExercise serialization', () {
    test('fromJson and toJson round-trip', () {
      final json = {
        'exercise_id': 3,
        'exercise_name': 'Bench Press',
        'sets': 4,
        'reps': 8,
        'duration_seconds': 90,
        'rest_seconds': 60,
        'image_url': 'bench.png',
      };

      final workoutExercise = WorkoutExercise.fromJson(json);
      final outputJson = workoutExercise.toJson();

      expect(workoutExercise.exerciseId, '3');
      expect(workoutExercise.exerciseName, 'Bench Press');
      expect(workoutExercise.restSeconds, 60);
      expect(outputJson['rest_seconds'], 60);
      expect(outputJson['image_url'], 'bench.png');
    });
  });
}
