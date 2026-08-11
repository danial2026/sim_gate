import 'package:sqflite/sqflite.dart';

import '../../models/sms_request.dart';

/// SQL access helpers for the `sms_requests` table.
class SmsQueries {
  SmsQueries(this._db);
  final Database _db;

  static const String _table = 'sms_requests';

  /// Inserts a new request row.
  Future<void> insert(SmsRequest request) async {
    await _db.insert(_table, request.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Updates mutable columns (status, retry counters, timestamps).
  Future<int> update(SmsRequest request) async {
    return _db.update(_table, request.toMap(),
        where: 'request_id = ?', whereArgs: [request.requestId]);
  }

  /// Cancels a pending/retrying request.
  Future<int> cancel(String requestId, DateTime at) async {
    return _db.update(
      _table,
      {
        'status': 'cancelled',
        'cancelled_at': at.toIso8601String(),
      },
      where: 'request_id = ? AND status IN (?, ?)',
      whereArgs: [requestId, 'pending', 'retrying'],
    );
  }

  /// Returns a single request by [requestId] or `null`.
  Future<SmsRequest?> getById(String requestId) async {
    final rows = await _db.query(_table,
        where: 'request_id = ?', whereArgs: [requestId], limit: 1);
    if (rows.isEmpty) return null;
    return SmsRequest.fromMap(rows.first);
  }

  /// Returns all requests that are pending or in retry state.
  Future<List<SmsRequest>> getPendingOrRetrying() async {
    final rows = await _db.query(
      _table,
      where: "status IN (?, ?)",
      whereArgs: ['pending', 'retrying'],
    );
    return rows.map(SmsRequest.fromMap).toList();
  }

  /// Returns the most recent [limit] logs for the dashboard.
  Future<List<SmsRequest>> getRecent({int limit = 10}) async {
    final rows = await _db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SmsRequest.fromMap).toList();
  }

  /// Filtered & paginated log query used by the Logs page and `/api/sms/logs`.
  Future<List<SmsRequest>> query({
    int limit = 20,
    int offset = 0,
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (status != null && status != 'all') {
      where.add('status = ?');
      args.add(status);
    }
    if (simId != null) {
      where.add('sim_id = ?');
      args.add(simId);
    }
    if (startDate != null) {
      where.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(recipient LIKE ? OR message LIKE ?)');
      final pattern = '%$searchQuery%';
      args.addAll([pattern, pattern]);
    }
    final rows = await _db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SmsRequest.fromMap).toList();
  }

  /// Counts requests grouped by status. Returns a map keyed by status name.
  Future<Map<String, int>> countsByStatus() async {
    final rows = await _db.rawQuery(
      'SELECT status, COUNT(*) as count FROM $_table GROUP BY status',
    );
    return {for (final r in rows) (r['status'] as String): (r['count'] as num).toInt()};
  }

  /// Average response time in milliseconds across sent requests.
  Future<int> averageResponseTimeMs() async {
    final rows = await _db.rawQuery(
      'SELECT AVG(response_time_ms) as avg_ms FROM retry_attempts '
      'WHERE status = ?',
      ['success'],
    );
    final value = rows.first['avg_ms'];
    if (value == null) return 0;
    return (value as num).round();
  }

  /// Total count of rows matching the same filter (for pagination totals).
  Future<int> totalCount({
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    final where = <String>[];
    final args = <Object>[];
    if (status != null && status != 'all') {
      where.add('status = ?');
      args.add(status);
    }
    if (simId != null) {
      where.add('sim_id = ?');
      args.add(simId);
    }
    if (startDate != null) {
      where.add('created_at >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      where.add('created_at <= ?');
      args.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(recipient LIKE ? OR message LIKE ?)');
      final pattern = '%$searchQuery%';
      args.addAll([pattern, pattern]);
    }
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      where.isEmpty ? null : args,
    );
    return (rows.first['count'] as num).toInt();
  }

  /// Hard delete all rows older than [days].
  Future<int> deleteOlderThan(Duration age) async {
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    return _db.delete(_table, where: 'created_at < ?', whereArgs: [cutoff]);
  }

  /// Returns the last [hours] of send counts grouped by hour bucket.
  /// Returns a list of `(hourBucket, count)` pairs ordered ascending.
  Future<List<({DateTime hour, int count})>> hourlyActivity({
    int hours = 24,
  }) async {
    final since = DateTime.now().toUtc().subtract(Duration(hours: hours));
    final rows = await _db.rawQuery(
      'SELECT created_at FROM $_table WHERE created_at >= ?',
      [since.toIso8601String()],
    );
    final buckets = <DateTime, int>{};
    for (final row in rows) {
      final created = DateTime.parse(row['created_at'] as String).toUtc();
      final bucket = DateTime.utc(created.year, created.month, created.day, created.hour);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
    // Fill missing buckets so charts render a continuous line.
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day, now.hour)
        .subtract(Duration(hours: hours - 1));
    final result = <({DateTime hour, int count})>[];
    for (var h = 0; h < hours; h++) {
      final bucket = start.add(Duration(hours: h));
      result.add((hour: bucket, count: buckets[bucket] ?? 0));
    }
    return result;
  }

  /// Deletes every row in the table. Used by maintenance/settings.
  Future<int> deleteAll() => _db.delete(_table);
}
