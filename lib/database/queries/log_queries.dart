import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/api_access_log.dart';
import '../../models/app_log.dart';
import '../../models/retry_attempt.dart';

/// SQL helpers for the `app_logs` table.
class LogQueries {
  LogQueries(this._db);
  final Database _db;

  static const String _table = 'app_logs';

  /// Inserts a single log row.
  Future<void> insert(AppLog log) async {
    final map = log.toMap();
    map['details'] = log.details == null ? null : jsonEncode(log.details);
    await _db.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final where = <String>[];
    final args = <Object>[];
    if (level != null) {
      where.add('log_level = ?');
      args.add(level.toUpperCase());
    }
    if (component != null) {
      where.add('component = ?');
      args.add(component.toUpperCase());
    }
    if (startDate != null) {
      where.add('timestamp >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('timestamp <= ?');
      args.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('message LIKE ?');
      args.add('%$searchQuery%');
    }
    final rows = await _db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      if (map['details'] != null) {
        map['details'] = jsonDecode(map['details'] as String);
      }
      return AppLog.fromMap(map);
    }).toList();
  }

  /// Deletes rows older than [days].
  Future<int> deleteOlderThan(Duration age) async {
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    return _db.delete(_table, where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  /// Trims the table to the most recent [maxEntries] rows.
  Future<int> trim(int maxEntries) async {
    final countRows = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table',
    );
    final count = (countRows.first['count'] as num).toInt();
    if (count <= maxEntries) return 0;
    final excess = count - maxEntries;
    await _db.rawQuery(
      'DELETE FROM $_table WHERE id IN (SELECT id FROM $_table '
      'ORDER BY timestamp ASC LIMIT ?)',
      [excess],
    );
    return excess;
  }

  Future<int> deleteAll() => _db.delete(_table);
}

/// SQL helpers for the `retry_attempts` table.
class RetryQueries {
  RetryQueries(this._db);
  final Database _db;

  static const String _table = 'retry_attempts';

  Future<void> insert(RetryAttempt attempt) async {
    await _db.insert(
      _table,
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all attempts for a request, ordered by attempt number.
  Future<List<RetryAttempt>> forRequest(String requestId) async {
    final rows = await _db.query(
      _table,
      where: 'request_id = ?',
      whereArgs: [requestId],
      orderBy: 'attempt_number ASC',
    );
    return rows.map(RetryAttempt.fromMap).toList();
  }

  /// Counts attempts for a single request.
  Future<int> countForRequest(String requestId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE request_id = ?',
      [requestId],
    );
    return (rows.first['count'] as num).toInt();
  }

  /// Returns the average success response time in ms across all attempts.
  Future<int> averageResponseTimeMs() async {
    final rows = await _db.rawQuery(
      'SELECT AVG(response_time_ms) as avg_ms FROM $_table WHERE status = ?',
      ['success'],
    );
    final value = rows.first['avg_ms'];
    if (value == null) return 0;
    return (value as num).round();
  }

  /// Deletes all attempts for a request.
  Future<int> deleteForRequest(String requestId) =>
      _db.delete(_table, where: 'request_id = ?', whereArgs: [requestId]);
}

/// SQL helpers for the `api_access_log` table.
class AccessLogQueries {
  AccessLogQueries(this._db);
  final Database _db;

  static const String _table = 'api_access_log';

  Future<void> insert(ApiAccessLog entry) async {
    await _db.insert(
      _table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the count of currently connected clients (unique IPs in last minute).
  Future<int> connectedClients() async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(minutes: 1))
        .toIso8601String();
    final rows = await _db.rawQuery(
      'SELECT COUNT(DISTINCT client_ip) as count FROM $_table WHERE timestamp >= ?',
      [since],
    );
    return (rows.first['count'] as num).toInt();
  }

  /// Total number of API requests received.
  Future<int> totalRequests() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) as count FROM $_table');
    return (rows.first['count'] as num).toInt();
  }

  Future<int> deleteAll() => _db.delete(_table);
}
