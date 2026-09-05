import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/progress/utils/progress_log_grouping.dart';
import 'package:synchrofit/shared/models/models.dart';

void main() {
  ProgressLog log(String id, DateTime date) => ProgressLog(
        id: id,
        title: 'Log $id',
        description: 'Description',
        weightKg: 70,
        imageUrl: 'https://example.test/$id',
        createdAt: date,
      );

  test('groups newest-first logs into newest-first month sections', () {
    final groups = groupProgressLogsByMonth([
      log('aug-old', DateTime(2026, 8, 1)),
      log('sep-old', DateTime(2026, 9, 2)),
      log('sep-new', DateTime(2026, 9, 20)),
    ]);

    expect(groups.keys.toList(), ['2026-09', '2026-08']);
    expect(groups['2026-09']!.map((item) => item.id).toList(), ['sep-new', 'sep-old']);
  });

  test('progress log serializes without losing timestamp or weight', () {
    final original = log('1', DateTime.utc(2026, 9, 5, 8));
    final decoded = ProgressLog.fromJson(original.toJson());
    expect(decoded.id, original.id);
    expect(decoded.weightKg, original.weightKg);
    expect(decoded.createdAt, original.createdAt);
  });
}
