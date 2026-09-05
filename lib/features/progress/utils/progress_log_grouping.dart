import '../../../shared/models/models.dart';

Map<String, List<ProgressLog>> groupProgressLogsByMonth(
  Iterable<ProgressLog> logs,
) {
  final sorted = logs.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <String, List<ProgressLog>>{};
  for (final log in sorted) {
    final local = log.createdAt.toLocal();
    final key = '${local.year}-${local.month.toString().padLeft(2, '0')}';
    groups.putIfAbsent(key, () => []).add(log);
  }
  return groups;
}
