import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/models/user.dart';
import 'package:synchrofit/shared/models/user_profile.dart';
import 'package:synchrofit/shared/models/exercise.dart';
import 'package:synchrofit/shared/models/workout.dart';
import 'package:synchrofit/shared/models/workout_exercise.dart';
import 'package:synchrofit/core/models/workout_history.dart';
import 'package:synchrofit/shared/models/completed_exercise.dart';
import 'package:synchrofit/shared/models/notification_item.dart';
import 'package:synchrofit/shared/models/enums.dart';

void main() {
  group('User serialization', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 1,
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john@example.com',
        'created_at': '2024-01-15T10:30:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, '1');
      expect(user.fullName, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.createdAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
    });

    test('toJson produces correct output', () {
      final user = User(
        id: '1',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        createdAt: DateTime.parse('2024-01-15T10:30:00.000Z'),
      );

      final json = user.toJson();

      expect(json['id'], '1');
      expect(json['first_name'], 'John');
      expect(json['last_name'], 'Doe');
      expect(json['email'], 'john@example.com');
      expect(json['created_at'], '2024-01-15T10:30:00.000Z');
    });
  });

  group('UserProfile serialization', () {
    test('fromJson parses correctly with enum mappings', () {
      final json = {
        'user_id': 42,
        'first_name': 'Jane',
        'last_name': '',
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
      const profile = UserProfile(
        userId: '1',
        firstName: 'Jane',
        lastName: '',
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
        'first_name': 'Test',
        'last_name': '',
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
        firstName: 'Jane',
        lastName: '',
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
        'video_path': 'https://example.com/pushup.png',
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
      expect(exercise.videoPath, 'https://example.com/pushup.png');
    });

    test('fromJson handles null equipment and video_path', () {
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
        'video_path': null,
      };

      final exercise = Exercise.fromJson(json);

      expect(exercise.equipment, null);
      expect(exercise.videoPath, null);
    });
  });

  group('Workout serialization', () {
    test('fromJson parses nested exercises', () {
      final json = {
        'id': 10,
        'user_id': 5,
        'name': 'Morning Workout',
        'day_of_week': 'monday',
        'estimated_duration_minutes': 45,
        'is_generated': false,
        'created_at': '2024-03-20T10:00:00.000Z',
        'updated_at': '2024-03-20T10:00:00.000Z',
        'exercises': [
          {
            'exercise_id': 1,
            'sets': 3,
            'reps': 12,
            'duration_seconds': 60,
            'order': 1,
          },
          {
            'exercise_id': 2,
            'sets': 4,
            'reps': 10,
            'duration_seconds': 45,
            'order': 2,
          },
        ],
      };

      final workout = Workout.fromJson(json);

      expect(workout.id, '10');
      expect(workout.userId, '5');
      expect(workout.name, 'Morning Workout');
      expect(workout.dayOfWeek, 'monday');
      expect(workout.estimatedDurationMinutes, 45);
      expect(workout.isGenerated, false);
      expect(workout.createdAt, DateTime.parse('2024-03-20T10:00:00.000Z'));
      expect(workout.exercises.length, 2);
      expect(workout.exercises[0].exerciseId, 1);
      expect(workout.exercises[0].order, 1);
      expect(workout.exercises[1].sets, 4);
      expect(workout.exercises[1].order, 2);
    });

    test('fromJson handles is_generated as true', () {
      final json = {
        'id': 11,
        'name': 'Generated Workout',
        'estimated_duration_minutes': 30,
        'is_generated': true,
        'exercises': [
          {
            'exercise_id': 1,
            'sets': 3,
            'reps': 10,
            'duration_seconds': 45,
            'order': 1,
          },
        ],
      };

      final workout = Workout.fromJson(json);

      expect(workout.isGenerated, true);
    });

    test('fromJson handles is_generated as integer 1 (SQLite)', () {
      final json = {
        'id': 12,
        'name': 'SQLite Workout',
        'estimated_duration_minutes': 30,
        'is_generated': 1,
        'exercises': [
          {
            'exercise_id': 1,
            'sets': 3,
            'reps': 10,
            'duration_seconds': 45,
            'order': 1,
          },
        ],
      };

      final workout = Workout.fromJson(json);

      expect(workout.isGenerated, true);
    });

    test('toJson serializes nested exercises', () {
      const workout = Workout(
        id: '1',
        userId: '42',
        name: 'Test',
        dayOfWeek: 'wednesday',
        estimatedDurationMinutes: 30,
        isGenerated: true,
        exercises: [
          WorkoutExercise(
            exerciseId: 1,
            sets: 3,
            reps: 10,
            durationSeconds: 60,
            order: 1,
          ),
        ],
      );

      final json = workout.toJson();

      expect(json['id'], '1');
      expect(json['user_id'], '42');
      expect(json['name'], 'Test');
      expect(json['day_of_week'], 'wednesday');
      expect(json['estimated_duration_minutes'], 30);
      expect(json['is_generated'], true);
      expect((json['exercises'] as List).length, 1);
      expect((json['exercises'] as List)[0]['exercise_id'], 1);
      expect((json['exercises'] as List)[0]['order'], 1);
    });

    test('toJson/fromJson round-trip preserves data', () {
      const original = Workout(
        id: '99',
        userId: '7',
        name: 'Full Body',
        dayOfWeek: 'friday',
        estimatedDurationMinutes: 60,
        isGenerated: false,
        exercises: [
          WorkoutExercise(
            exerciseId: 5,
            sets: 4,
            reps: 12,
            durationSeconds: 90,
            order: 1,
          ),
          WorkoutExercise(
            exerciseId: 8,
            sets: 3,
            reps: 15,
            durationSeconds: 60,
            order: 2,
          ),
        ],
      );

      final json = original.toJson();
      final restored = Workout.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.name, original.name);
      expect(restored.dayOfWeek, original.dayOfWeek);
      expect(
          restored.estimatedDurationMinutes, original.estimatedDurationMinutes);
      expect(restored.isGenerated, original.isGenerated);
      expect(restored.exercises.length, original.exercises.length);
      expect(
          restored.exercises[0].exerciseId, original.exercises[0].exerciseId);
      expect(restored.exercises[1].order, original.exercises[1].order);
    });
  });

  group('WorkoutHistory serialization', () {
    test('fromJson parses exercises completed', () {
      final json = {
        'id': 100,
        'user_id': 10,
        'workout_name': 'Leg Day',
        'completed_at': '2024-03-20T14:30:00.000Z',
        'total_duration_seconds': 2700,
        'exercises_completed': [
          {
            'exercise_id': 1,
            'exercise_name': 'Squats',
            'sets_completed': 3,
            'reps_or_duration': 12,
          },
        ],
      };

      final history = WorkoutHistory.fromJson(json);

      expect(history.id, '100');
      expect(history.userId, '10');
      expect(history.workoutName, 'Leg Day');
      expect(history.totalDurationSeconds, 2700);
      expect(history.exercisesCompleted.length, 1);
      expect(history.exercises[0].setsCompleted, 3);
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
        'sets': 4,
        'reps': 8,
        'duration_seconds': 90,
        'order': 2,
      };

      final workoutExercise = WorkoutExercise.fromJson(json);
      final outputJson = workoutExercise.toJson();

      expect(workoutExercise.exerciseId, 3);
      expect(workoutExercise.sets, 4);
      expect(workoutExercise.reps, 8);
      expect(workoutExercise.durationSeconds, 90);
      expect(workoutExercise.order, 2);
      expect(outputJson['exercise_id'], 3);
      expect(outputJson['sets'], 4);
      expect(outputJson['reps'], 8);
      expect(outputJson['duration_seconds'], 90);
      expect(outputJson['order'], 2);
    });

    test('keeps rest separate from exercise duration', () {
      final exercise = WorkoutExercise.fromJson({
        'exercise_id': 3,
        'sets': 4,
        'reps': 8,
        'rest_seconds': 90,
        'order': 2,
      });

      expect(exercise.durationSeconds, 0);
      expect(exercise.restSeconds, 90);
    });
  });
}
