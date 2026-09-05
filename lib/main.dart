import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/local/database_provider.dart';
import 'data/local/local_database.dart';
import 'data/sync/sync_providers.dart';
import 'features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize the Android local database with graceful degradation.
  // If SQLite initialization fails, the app runs without offline caching
  // and uses remote repositories directly.
  LocalDatabaseImpl? database;
  try {
    database = LocalDatabaseImpl();
    await database.initialize();
  } catch (e, stack) {
    debugPrint('Local database initialization failed: $e');
    debugPrint('$stack');
    database = null;
  }

  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (database != null) localDatabaseProvider.overrideWithValue(database),
  ];

  final container = ProviderContainer(overrides: overrides);

  if (database != null) {
    try {
      container.read(syncEngineProvider);
    } catch (e) {
      debugPrint('SyncEngine initialization failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
