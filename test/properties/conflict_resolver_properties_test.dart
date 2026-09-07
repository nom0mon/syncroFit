// Feature: offline-support-and-ui-enhancements, Property 4: Conflict resolution is deterministic — last-write-wins
import 'package:glados/glados.dart';
import 'package:synchrofit/data/sync/conflict_resolver.dart';

/// **Validates: Requirements 5.1, 5.2**
///
/// Property 4: Conflict resolution is deterministic — last-write-wins
///
/// For any pair of timestamps (localMutationTimestamp, serverUpdatedAt),
/// the ConflictResolver SHALL return `true` (apply local) if and only if
/// localMutationTimestamp is strictly after serverUpdatedAt; otherwise it
/// SHALL return `false` (server wins).
void main() {
  final resolver = ConflictResolver();

  group('Property 4: Conflict resolution is deterministic — last-write-wins',
      () {
    Glados2(any.int, any.int).test(
      'shouldApplyLocal returns true iff localTimestamp.isAfter(serverTimestamp)',
      (localOffsetMs, serverOffsetMs) {
        // Generate two arbitrary DateTime values using offsets from a base epoch
        final base = DateTime(2020, 1, 1);
        final localTimestamp = base.add(Duration(milliseconds: localOffsetMs));
        final serverTimestamp =
            base.add(Duration(milliseconds: serverOffsetMs));

        final result = resolver.shouldApplyLocal(
          localMutationTimestamp: localTimestamp,
          serverUpdatedAt: serverTimestamp,
        );

        final expected = localTimestamp.isAfter(serverTimestamp);

        expect(
          result,
          equals(expected),
          reason:
              'shouldApplyLocal($localTimestamp, $serverTimestamp) returned $result '
              'but expected $expected',
        );
      },
    );

    Glados(any.int).test(
      'equal timestamps always result in server wins (returns false)',
      (offsetMs) {
        final base = DateTime(2020, 1, 1);
        final timestamp = base.add(Duration(milliseconds: offsetMs));

        final result = resolver.shouldApplyLocal(
          localMutationTimestamp: timestamp,
          serverUpdatedAt: timestamp,
        );

        expect(
          result,
          isFalse,
          reason:
              'Equal timestamps ($timestamp) should result in server wins (false), '
              'but got $result',
        );
      },
    );

    Glados2(any.int, any.positiveIntOrZero).test(
      'local strictly after server always returns true',
      (baseOffsetMs, positiveDeltaMs) {
        // Ensure local is strictly after server by adding a positive delta > 0
        final delta = positiveDeltaMs + 1; // guarantee > 0
        final base = DateTime(2020, 1, 1);
        final serverTimestamp = base.add(Duration(milliseconds: baseOffsetMs));
        final localTimestamp =
            serverTimestamp.add(Duration(milliseconds: delta));

        final result = resolver.shouldApplyLocal(
          localMutationTimestamp: localTimestamp,
          serverUpdatedAt: serverTimestamp,
        );

        expect(
          result,
          isTrue,
          reason: 'Local ($localTimestamp) is after server ($serverTimestamp), '
              'should return true but got $result',
        );
      },
    );

    Glados2(any.int, any.positiveIntOrZero).test(
      'server strictly after local always returns false',
      (baseOffsetMs, positiveDeltaMs) {
        // Ensure server is strictly after local by adding a positive delta > 0
        final delta = positiveDeltaMs + 1; // guarantee > 0
        final base = DateTime(2020, 1, 1);
        final localTimestamp = base.add(Duration(milliseconds: baseOffsetMs));
        final serverTimestamp =
            localTimestamp.add(Duration(milliseconds: delta));

        final result = resolver.shouldApplyLocal(
          localMutationTimestamp: localTimestamp,
          serverUpdatedAt: serverTimestamp,
        );

        expect(
          result,
          isFalse,
          reason: 'Server ($serverTimestamp) is after local ($localTimestamp), '
              'should return false but got $result',
        );
      },
    );
  });
}
