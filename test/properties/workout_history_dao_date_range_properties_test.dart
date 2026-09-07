// Feature: database-simplification, Property 9: WorkoutHistory DAO date range query correctness
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, setUpAll, setUp, tearDown, test;
import 'package:glados/glados.dart' as glados show any;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:synchrofit/core/models/workout_history.dart';
import 'package:synchrofit/data/local/daos/workout_history_dao.dart';

/// **Validates: Requirements 11.5**
///
/// Property 9: WorkoutHistory DAO date range query correctness
///
/// For any set of WorkoutHistory records with various completedAt timestamps
/// and for any date range [start, end], querying the DAO by that range SHALL
/// return exactly those records whose completedAt falls within the range
/// (inclusive).
void main() {
  // Initialize sqflite FFI for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  /// Helper to create a fresh in-memory database with the workout_history table
  Future<(Database, WorkoutHistoryDao)> createDb() async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE workout_history (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              workout_name TEXT NOT NULL,
              completed_at TEXT NOT NULL,
              total_duration_seconds INTEGER NOT NULL,
              exercises_completed TEXT NOT NULL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
        },
      ),
    );
    return (db, WorkoutHistoryDao(db));
  }

  group('Property 9: WorkoutHistory DAO date range query correctness', () {
    // ─────────────────────────────────────────────────────────────────────
    // Test 1: Generate records spread across a time window and verify
    // date range query returns exactly the correct subset
    // ─────────────────────────────────────────────────────────────────────
    Glados3(
      glados.any.intInRange(1, 15), // number of records to insert
      glados.any.intInRange(0, 300), // start day offset from base
      glados.any.intInRange(0, 300), // end day offset from base
    ).test(
      'getByDateRange returns exactly records whose completedAt is within [start, end] inclusive',
      (recordCount, startOffset, endOffset) async {
        final (db, dao) = await createDb();
        try {
          const userId = 'test-user-date-range';
          final baseDate = DateTime(2023, 1, 1);

          // Generate records with timestamps spread across a 365-day window
          final records = List.generate(recordCount, (i) {
            // Spread completedAt evenly across a year
            final daysOffset = (i * 365) ~/ recordCount;
            final completedAt = baseDate.add(Duration(days: daysOffset));

            return WorkoutHistory(
              id: 'wh-range-$i',
              userId: userId,
              workoutName: 'Workout $i',
              completedAt: completedAt,
              totalDurationSeconds: 1800 + (i * 60),
              exercisesCompleted: [
                {
                  'exercise_id': i + 1,
                  'exercise_name': 'Exercise $i',
                  'sets_completed': 3,
                  'reps_completed': 10,
                  'skipped': false,
                },
              ],
              createdAt: completedAt,
              updatedAt: completedAt,
            );
          });

          // Insert all records
          for (final record in records) {
            await dao.insertRecord(record);
          }

          // Define the query range using the generated offsets
          // Ensure start <= end by sorting them
          final rangeStart = startOffset <= endOffset ? startOffset : endOffset;
          final rangeEnd = startOffset <= endOffset ? endOffset : startOffset;

          final queryStart = baseDate.add(Duration(days: rangeStart));
          final queryEnd = baseDate.add(Duration(days: rangeEnd));

          // Query the DAO
          final results =
              await dao.getByDateRange(userId, queryStart, queryEnd);

          // Compute expected results by filtering records whose completedAt
          // falls within [queryStart, queryEnd] inclusive using ISO 8601
          // string comparison (matching the DAO implementation)
          final queryStartStr = queryStart.toIso8601String();
          final queryEndStr = queryEnd.toIso8601String();

          final expected = records.where((r) {
            final completedAtStr = r.completedAt.toIso8601String();
            return completedAtStr.compareTo(queryStartStr) >= 0 &&
                completedAtStr.compareTo(queryEndStr) <= 0;
          }).toList();

          // Verify result count matches expected
          expect(
            results.length,
            equals(expected.length),
            reason: 'Expected ${expected.length} records in range '
                '[$queryStart, $queryEnd], got ${results.length}. '
                'Records: ${records.map((r) => r.completedAt).toList()}',
          );

          // Verify all returned records are in the expected set
          final resultIds = results.map((r) => r.id).toSet();
          final expectedIds = expected.map((r) => r.id).toSet();
          expect(resultIds, equals(expectedIds));
        } finally {
          await db.close();
        }
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 2: Verify exact boundary inclusiveness (records at start and end
    // of the range are included)
    // ─────────────────────────────────────────────────────────────────────
    Glados2(
      glados.any.intInRange(0, 200), // days for the range boundary
      glados.any.intInRange(1, 10), // number of records at boundary
    ).test(
      'getByDateRange includes records exactly at start and end boundaries',
      (dayOffset, boundaryRecordCount) async {
        final (db, dao) = await createDb();
        try {
          const userId = 'test-user-boundary';
          final baseDate = DateTime(2024, 1, 1);
          final boundaryDate = baseDate.add(Duration(days: dayOffset));

          // Insert records exactly at the boundary timestamp
          for (int i = 0; i < boundaryRecordCount; i++) {
            final record = WorkoutHistory(
              id: 'wh-boundary-$dayOffset-$i',
              userId: userId,
              workoutName: 'Boundary Workout $i',
              completedAt: boundaryDate,
              totalDurationSeconds: 1200,
              exercisesCompleted: [
                {
                  'exercise_id': 1,
                  'exercise_name': 'Push Ups',
                  'sets_completed': 3,
                  'reps_completed': 12,
                  'skipped': false,
                },
              ],
              createdAt: boundaryDate,
              updatedAt: boundaryDate,
            );
            await dao.insertRecord(record);
          }

          // Also insert a record clearly outside the range (1 day after)
          final outsideRecord = WorkoutHistory(
            id: 'wh-boundary-outside-$dayOffset',
            userId: userId,
            workoutName: 'Outside Workout',
            completedAt: boundaryDate.add(const Duration(days: 1)),
            totalDurationSeconds: 900,
            exercisesCompleted: [],
            createdAt: boundaryDate.add(const Duration(days: 1)),
            updatedAt: boundaryDate.add(const Duration(days: 1)),
          );
          await dao.insertRecord(outsideRecord);

          // Query with the range exactly [boundaryDate, boundaryDate]
          final results =
              await dao.getByDateRange(userId, boundaryDate, boundaryDate);

          // All boundary records should be included, outside record excluded
          expect(
            results.length,
            equals(boundaryRecordCount),
            reason:
                'Expected $boundaryRecordCount records at boundary $boundaryDate, '
                'got ${results.length}',
          );

          // Verify none of the results are the outside record
          for (final result in results) {
            expect(result.id, isNot(equals('wh-boundary-outside-$dayOffset')));
          }
        } finally {
          await db.close();
        }
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 3: Verify that records for a different user are not returned
    // ─────────────────────────────────────────────────────────────────────
    Glados2(
      glados.any.intInRange(1, 8), // records for target user
      glados.any.intInRange(1, 8), // records for other user
    ).test(
      'getByDateRange only returns records for the specified userId',
      (targetCount, otherCount) async {
        final (db, dao) = await createDb();
        try {
          const targetUser = 'target-user';
          const otherUser = 'other-user';
          final baseDate = DateTime(2024, 3, 1);

          // Insert records for target user
          for (int i = 0; i < targetCount; i++) {
            final record = WorkoutHistory(
              id: 'wh-target-$i',
              userId: targetUser,
              workoutName: 'Target Workout $i',
              completedAt: baseDate.add(Duration(days: i)),
              totalDurationSeconds: 1800,
              exercisesCompleted: [
                {
                  'exercise_id': 1,
                  'exercise_name': 'Ex',
                  'sets_completed': 3,
                  'reps_completed': 10,
                  'skipped': false
                },
              ],
              createdAt: baseDate,
              updatedAt: baseDate,
            );
            await dao.insertRecord(record);
          }

          // Insert records for other user within the same date range
          for (int i = 0; i < otherCount; i++) {
            final record = WorkoutHistory(
              id: 'wh-other-$i',
              userId: otherUser,
              workoutName: 'Other Workout $i',
              completedAt: baseDate.add(Duration(days: i)),
              totalDurationSeconds: 2400,
              exercisesCompleted: [
                {
                  'exercise_id': 2,
                  'exercise_name': 'Ex2',
                  'sets_completed': 4,
                  'reps_completed': 8,
                  'skipped': false
                },
              ],
              createdAt: baseDate,
              updatedAt: baseDate,
            );
            await dao.insertRecord(record);
          }

          // Query with a range that covers all records
          final rangeEnd =
              baseDate.add(Duration(days: targetCount + otherCount));
          final results =
              await dao.getByDateRange(targetUser, baseDate, rangeEnd);

          // Should only return the target user's records
          expect(results.length, equals(targetCount));
          for (final result in results) {
            expect(result.userId, equals(targetUser));
          }
        } finally {
          await db.close();
        }
      },
    );

    // ─────────────────────────────────────────────────────────────────────
    // Test 4: Empty range (no records in range) returns empty list
    // ─────────────────────────────────────────────────────────────────────
    Glados(glados.any.intInRange(1, 10)).test(
      'getByDateRange returns empty list when no records fall within range',
      (recordCount) async {
        final (db, dao) = await createDb();
        try {
          const userId = 'test-user-empty';
          final baseDate = DateTime(2024, 6, 1);

          // Insert records in June 2024
          for (int i = 0; i < recordCount; i++) {
            final record = WorkoutHistory(
              id: 'wh-empty-$i',
              userId: userId,
              workoutName: 'June Workout $i',
              completedAt: baseDate.add(Duration(days: i)),
              totalDurationSeconds: 1500,
              exercisesCompleted: [],
              createdAt: baseDate,
              updatedAt: baseDate,
            );
            await dao.insertRecord(record);
          }

          // Query a range entirely in January 2024 (before all records)
          final queryStart = DateTime(2024, 1, 1);
          final queryEnd = DateTime(2024, 1, 31);
          final results =
              await dao.getByDateRange(userId, queryStart, queryEnd);

          expect(results, isEmpty,
              reason: 'Expected no records in January range');
        } finally {
          await db.close();
        }
      },
    );
  });
}
