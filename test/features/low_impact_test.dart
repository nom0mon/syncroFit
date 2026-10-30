import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:synchrofit/data/repositories/profile_repository.dart';
import 'package:synchrofit/data/repositories/workout_repository.dart';
import 'package:synchrofit/features/profile/providers/profile_edit_notifier.dart';
import 'package:synchrofit/shared/models/models.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

/// Shared helpers and data for all low-impact tests.
UserProfile _baseProfile({bool lowImpactOnly = false}) => UserProfile(
      userId: 'user-1',
      firstName: 'Sam',
      lastName: 'Green',
      age: 28,
      heightCm: 170.0,
      weightKg: 75.0,
      gender: Gender.male,
      fitnessGoal: FitnessGoal.buildMuscle,
      fitnessLevel: FitnessLevel.intermediate,
      workoutPreference: WorkoutPreference.gym,
      workoutAvailability: const [DayOfWeek.monday, DayOfWeek.wednesday],
      lowImpactOnly: lowImpactOnly,
    );

// ---------------------------------------------------------------------------
// UserProfile model
// ---------------------------------------------------------------------------

void main() {
  group('UserProfile – lowImpactOnly field', () {
    test('defaults to false when not supplied to the constructor', () {
      final p = _baseProfile();
      expect(p.lowImpactOnly, isFalse);
    });

    test('round-trips true through toJson/fromJson', () {
      final original = _baseProfile(lowImpactOnly: true);
      final json = original.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.lowImpactOnly, isTrue);
    });

    test('round-trips false through toJson/fromJson', () {
      final original = _baseProfile(lowImpactOnly: false);
      final json = original.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.lowImpactOnly, isFalse);
    });

    test('toApiJson includes low_impact_only', () {
      expect(_baseProfile(lowImpactOnly: true).toApiJson()['low_impact_only'], isTrue);
      expect(_baseProfile().toApiJson()['low_impact_only'], isFalse);
    });

    test('fromJson defaults to false when key is absent (older payloads)', () {
      final json = _baseProfile().toJson()..remove('low_impact_only');
      expect(UserProfile.fromJson(json).lowImpactOnly, isFalse);
    });

    test('fromJson accepts SQLite integer 1 as true and 0 as false', () {
      final base = _baseProfile().toJson();
      expect(UserProfile.fromJson({...base, 'low_impact_only': 1}).lowImpactOnly, isTrue);
      expect(UserProfile.fromJson({...base, 'low_impact_only': 0}).lowImpactOnly, isFalse);
    });

    test('fromJson accepts string "1" and "true" as true', () {
      final base = _baseProfile().toJson();
      expect(UserProfile.fromJson({...base, 'low_impact_only': '1'}).lowImpactOnly, isTrue);
      expect(UserProfile.fromJson({...base, 'low_impact_only': 'true'}).lowImpactOnly, isTrue);
    });
  });

// ---------------------------------------------------------------------------
// ProfileEditNotifier – low_impact_only dirty-field tracking
// ---------------------------------------------------------------------------

  group('ProfileEditNotifier – low_impact_only field', () {
    late MockProfileRepository repo;
    late ProfileEditNotifier notifier;

    setUp(() {
      repo = MockProfileRepository();
      notifier = ProfileEditNotifier(
        profileRepository: repo,
        originalProfile: _baseProfile(lowImpactOnly: false),
      );
      registerFallbackValue(_baseProfile());
    });

    test('not dirty when toggled back to original value', () {
      notifier.updateField('low_impact_only', true);
      expect(notifier.state.isDirty, isTrue);

      notifier.updateField('low_impact_only', false);
      expect(notifier.state.isDirty, isFalse);
    });

    test('marks state dirty when value differs from original', () {
      notifier.updateField('low_impact_only', true);
      expect(notifier.state.dirtyFields['low_impact_only'], isTrue);
      expect(notifier.state.isDirty, isTrue);
    });

    test('save() includes lowImpactOnly in updated profile', () async {
      when(() => repo.updateProfile(any()))
          .thenAnswer((_) async => Success(_baseProfile(lowImpactOnly: true)));

      notifier.updateField('low_impact_only', true);
      await notifier.save();

      final captured = verify(() => repo.updateProfile(captureAny())).captured;
      final saved = captured.first as UserProfile;
      expect(saved.lowImpactOnly, isTrue);
      expect(notifier.state.isSuccess, isTrue);
    });

    test('save() preserves original lowImpactOnly when field not touched', () async {
      final original = _baseProfile(lowImpactOnly: true);
      final localNotifier = ProfileEditNotifier(
        profileRepository: repo,
        originalProfile: original,
      );
      when(() => repo.updateProfile(any()))
          .thenAnswer((_) async => Success(original));

      localNotifier.updateField('first_name', 'Changed');
      await localNotifier.save();

      final captured = verify(() => repo.updateProfile(captureAny())).captured;
      final saved = captured.first as UserProfile;
      expect(saved.lowImpactOnly, isTrue);
    });
  });

// ---------------------------------------------------------------------------
// GenerationResult – unresolved slots parsing
// ---------------------------------------------------------------------------

// These tests are unit tests against the value object only.
// The full API response parsing is covered by integration tests.

  group('GenerationResult – value object', () {
    test('defaults unresolvedSlots to zero', () {
      final r = GenerationResult(workouts: const []);
      expect(r.unresolvedSlots, 0);
    });

    test('stores non-zero unresolvedSlots', () {
      final r = GenerationResult(workouts: const [], unresolvedSlots: 5);
      expect(r.unresolvedSlots, 5);
    });

    test('carries the workouts list through', () {
      final workouts = [
        const Workout(
          id: '1',
          name: 'Full Body',
          estimatedDurationMinutes: 30,
          exercises: [],
        ),
      ];
      final r = GenerationResult(workouts: workouts, unresolvedSlots: 1);
      expect(r.workouts, equals(workouts));
      expect(r.unresolvedSlots, 1);
    });
  });
}
