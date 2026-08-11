import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';

/// Shared test helpers for DB-backed tests.
///
/// Each harness gets a *unique* in-memory SQLite database (the FFI factory
/// caches databases by path, so reusing `:memory:` across tests re-opens the
/// same schema and breaks migrations). Tests never touch platform channels.
class TestHarness {
  TestHarness._(this._dbPath);

  final String _dbPath;
  SharedPreferences? prefs;

  static int _counter = 0;

  /// Builds a unique shared-memory DB path, e.g.
  /// `file:sim_gate_test_3?mode=memory&cache=shared`.
  static String nextDbPath() {
    _counter++;
    return 'file:sim_gate_test_$_counter?mode=memory&cache=shared';
  }

  /// Creates a fresh harness and rewires the DI container.
  static Future<TestHarness> create() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({});
    final harness = TestHarness._(nextDbPath());
    harness.prefs = await SharedPreferences.getInstance();
    // In-process sqlite (no background isolate) so DB futures complete under
    // the widget-test FakeAsync zone; unit tests benefit too.
    DatabaseHelper.overrideFactory = databaseFactoryFfiNoIsolate;
    await setupForTest(prefs: harness.prefs!, dbPath: harness._dbPath);
    return harness;
  }

  /// Closes the registered database and resets DI between tests.
  Future<void> dispose() async {
    try {
      await getIt<DatabaseHelper>().close();
    } catch (_) {
      // Ignore double-close.
    }
    await resetGetIt();
  }
}
