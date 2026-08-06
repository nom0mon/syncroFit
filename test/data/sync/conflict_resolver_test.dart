import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/data/sync/conflict_resolver.dart';

void main() {
  late ConflictResolver resolver;

  setUp(() {
    resolver = ConflictResolver();
  });

  group('ConflictResolver - shouldApplyLocal', () {
    test('returns true when local timestamp is after server timestamp', () {
      final localTimestamp = DateTime(2024, 6, 15, 12, 30, 0);
      final serverTimestamp = DateTime(2024, 6, 15, 12, 0, 0);

      final result = resolver.shouldApplyLocal(
        localMutationTimestamp: localTimestamp,
        serverUpdatedAt: serverTimestamp,
      );

      expect(result, isTrue);
    });

    test('returns false when server timestamp is after local timestamp', () {
      final localTimestamp = DateTime(2024, 6, 15, 12, 0, 0);
      final serverTimestamp = DateTime(2024, 6, 15, 12, 30, 0);

      final result = resolver.shouldApplyLocal(
        localMutationTimestamp: localTimestamp,
        serverUpdatedAt: serverTimestamp,
      );

      expect(result, isFalse);
    });

    test('returns false when timestamps are equal (server wins ties)', () {
      final timestamp = DateTime(2024, 6, 15, 12, 0, 0);

      final result = resolver.shouldApplyLocal(
        localMutationTimestamp: timestamp,
        serverUpdatedAt: timestamp,
      );

      expect(result, isFalse);
    });

    test('returns true when local is 1 millisecond after server', () {
      final serverTimestamp = DateTime(2024, 6, 15, 12, 0, 0, 0);
      final localTimestamp = DateTime(2024, 6, 15, 12, 0, 0, 1);

      final result = resolver.shouldApplyLocal(
        localMutationTimestamp: localTimestamp,
        serverUpdatedAt: serverTimestamp,
      );

      expect(result, isTrue);
    });

    test('returns false when local is 1 millisecond before server', () {
      final localTimestamp = DateTime(2024, 6, 15, 12, 0, 0, 0);
      final serverTimestamp = DateTime(2024, 6, 15, 12, 0, 0, 1);

      final result = resolver.shouldApplyLocal(
        localMutationTimestamp: localTimestamp,
        serverUpdatedAt: serverTimestamp,
      );

      expect(result, isFalse);
    });
  });
}
