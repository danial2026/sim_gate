import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';

/// Permission status code reported by the mocked platform channel.
const int _permissionGranted = 1;

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

  /// Stubs the permission_handler method channel so status/request calls
  /// complete inside the widget-test FakeAsync zone (the real platform reply
  /// never arrives there) and report every permission as granted.
  ///
  /// Only applies when a widget-test binding exists: plain `test()` suites
  /// (e.g. e2e) must keep real networking, which TestWidgetsFlutterBinding
  /// would stub out.
  static void _mockPermissionChannel() {
    TestWidgetsFlutterBinding? binding;
    try {
      binding = TestWidgetsFlutterBinding.instance;
    } catch (_) {
      return; // plain test() suite: no widget binding; keep real HTTP.
    }
    if (binding == null) return;
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return _permissionGranted;
        case 'requestPermissions':
          return const <int, int>{};
        default:
          return null;
      }
    });
  }

  /// Creates a fresh harness and rewires the DI container.
  static Future<TestHarness> create() async {
    sqfliteFfiInit();
    _mockPermissionChannel();
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
