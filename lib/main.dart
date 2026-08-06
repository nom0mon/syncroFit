import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'data/local/database_provider.dart';
import 'data/local/local_database.dart';
import 'data/sync/sync_providers.dart';
import 'features/settings/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize the local database with graceful degradation.
  // If SQLite is not available (web without WASM), the app runs without
  // offline caching and uses remote repositories directly.
  LocalDatabaseImpl? database;
  try {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
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
