import 'package:uuid/uuid.dart';

import '../models/app_log.dart';
import '../repositories/logs_repository.dart';
import '../utils/logger.dart';

/// A [LogSink] that persists each [LogEntry] into the SQLite `app_logs` table.
class DatabaseLogSink implements LogSink {
  DatabaseLogSink(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LogsRepository _repo;
  final Uuid _uuid;

  @override
  void write(LogEntry entry) {
    // Fire-and-forget insert. We encode details as JSON for storage.
    final log = AppLog(
      id: _uuid.v4(),
      level: entry.level,
      component: entry.component,
      message: entry.message,
      details: entry.details,
      timestamp: entry.timestamp,
      stackTrace: entry.stackTrace,
    );
    // ignore: discarded_futures
    _repo.insert(log).catchError((Object e) {
      // Avoid recursion: print only.
      // ignore: avoid_print
      print('DatabaseLogSink insert failed: $e');
    });
  }
}

/// Service that owns the [Logger] and wires up sinks at app startup.
class LoggerService {
  LoggerService({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Logger get logger => _logger;

  /// Attaches the database-backed sink so log entries persist.
  void attachDatabaseSink(LogsRepository repo, {Uuid? uuid}) {
    _logger.attachSink(DatabaseLogSink(repo, uuid: uuid));
  }

  /// Sets the minimum level from the stored configuration string.
  void setMinLevelString(String value) {
    _logger.minLevel = parseLogLevel(value);
  }
}
