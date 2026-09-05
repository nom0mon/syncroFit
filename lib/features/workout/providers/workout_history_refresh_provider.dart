import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Increments whenever a completed workout has been persisted.
///
/// Dashboard and Progress watch this value so cached summaries are rebuilt as
/// soon as a session is recorded, including while their tabs stay mounted.
final workoutHistoryRefreshProvider = StateProvider<int>((ref) => 0);
