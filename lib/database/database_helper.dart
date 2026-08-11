import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';
import 'migrations/migration_001_initial.dart';

/// Schema migrations applied in order when the database is opened.
typedef Migration = Future<void> Function(Database db);

/// SQLite access point for the SimGate app.
///
/// The helper is intentionally backend-agnostic: tests inject an FFI factory
/// via [overrideFactory], while the production app uses the platform default
/// (sqflite_android on Android).
class DatabaseHelper {
  DatabaseHelper({DatabaseFactory? factory, String? pathOverride})
      : _factoryOverride = factory,
        _pathOverride = pathOverride;

  final DatabaseFactory? _factoryOverride;
  final String? _pathOverride;

  Database? _db;
  final _logger = Logger(minLevel: LogLevel.info);

  /// Migrations applied in ascending order. New migrations append to this list.
  static final List<Migration> migrations = [
    migration001Initial,
  ];

  /// Optional factory override for tests (e.g. `databaseFactoryFfi`).
  static DatabaseFactory? overrideFactory;

  /// Lazily opens and returns the database, applying all migrations.
  Future<Database> database() async {
    if (_db != null && _db!.isOpen) return _db!;

    final factory = _factoryOverride ?? overrideFactory ?? databaseFactory;
    final path = _pathOverride ??
        p.join(await factory.getDatabasesPath(), AppConstants.databaseName);

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onCreate: (db, version) async {
          _logger.info(LogComponent.database, 'Creating database v$version');
          for (final migration in migrations) {
            await migration(db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          _logger.info(
            LogComponent.database,
            'Upgrading database $oldVersion -> $newVersion',
          );
          for (var i = oldVersion; i < newVersion && i < migrations.length; i++) {
            await migrations[i](db);
          }
        },
      ),
    );
    return _db!;
  }

  /// Closes the database. Safe to call multiple times.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
  }

  /// Convenience wrapper for deletion (used by tests to reset state).
  Future<void> deleteDatabase() async {
    final factory = _factoryOverride ?? overrideFactory ?? databaseFactory;
    final path = _pathOverride ??
        p.join(await factory.getDatabasesPath(), AppConstants.databaseName);
    await factory.deleteDatabase(path);
    _db = null;
  }
}
