import '../database/database_helper.dart';
import '../database/queries/log_queries.dart';
import '../models/api_access_log.dart';
import '../models/app_log.dart';

/// Repository for the `app_logs` table.
class LogsRepository {
  LogsRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;
  LogQueries? _logQ;
  AccessLogQueries? _accessQ;

  Future<LogQueries> _log() async {
    _logQ ??= LogQueries(await _dbHelper.database());
    return _logQ!;
  }

  Future<AccessLogQueries> _access() async {
    _accessQ ??= AccessLogQueries(await _dbHelper.database());
    return _accessQ!;
  }

  /// Inserts an app log entry.
  Future<void> insert(AppLog log) async {
    final q = await _log();
    await q.insert(log);
  }

  /// Filtered & paginated query.
  Future<List<AppLog>> query({
    int limit = 50,
    int offset = 0,
    String? level,
    String? component,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final q = await _log();
    return q.query(
      limit: limit,
      offset: offset,
      level: level,
      component: component,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Records an API access log entry.
  Future<void> recordAccess(ApiAccessLog entry) async {
    final q = await _access();
    await q.insert(entry);
  }

  /// Number of distinct client IPs in the last minute (connected clients).
  Future<int> connectedClients() async {
    final q = await _access();
    return q.connectedClients();
  }

  /// Total API requests received.
  Future<int> totalApiRequests() async {
    final q = await _access();
    return q.totalRequests();
  }

  /// Deletes logs older than [age].
  Future<int> purgeOlderThan(Duration age) async {
    final q = await _log();
    return q.deleteOlderThan(age);
  }

  /// Trims the log table to the most recent [maxEntries] rows.
  Future<int> trim(int maxEntries) async {
    final q = await _log();
    return q.trim(maxEntries);
  }

  /// Clears all app logs.
  Future<int> deleteAll() async {
    final q = await _log();
    return q.deleteAll();
  }

  /// Clears all access logs.
  Future<int> deleteAllAccess() async {
    final q = await _access();
    return q.deleteAll();
  }
}
