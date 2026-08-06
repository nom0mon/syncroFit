import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_database.dart';

/// Riverpod provider for the [LocalDatabase] singleton.
///
/// The database must be initialized before use by calling:
/// ```dart
/// final db = ref.read(localDatabaseProvider);
/// await db.initialize();
/// ```
///
/// Typically called once during app startup in `main.dart`.
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabaseImpl();

  ref.onDispose(() async {
    await database.close();
  });

  return database;
});
