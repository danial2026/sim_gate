import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';

/// Shared test helpers for DB-backed tests.
///
/// Sets up an in-memory FFI database and mock prefs so tests never touch the
/// platform channels or a real device.
class TestHarness {
  TestHarness._();

  final DatabaseHelper dbHelper = DatabaseHelper(pathOverride: inMemoryDbPath);
  SharedPreferences? prefs;

  /// Path that forces an in-memory DB (per-open).
  static const String inMemoryDbPath = ':memory:';

  /// Creates a fresh harness and rewires the DI container.
  static Future<TestHarness> create() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final harness = TestHarness._();
    harness.prefs = await SharedPreferences.getInstance();
    DatabaseHelper.overrideFactory = databaseFactoryFfi;
    await setupForTest(prefs: harness.prefs!, dbPath: inMemoryDbPath);
    return harness;
  }

  /// Drops the in-memory database between tests.
  Future<void> dispose() async {
    await dbHelper.deleteDatabase();
    await resetGetIt();
  }
}
