import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';
import '../database/queries/log_queries.dart';
import '../database/queries/sms_queries.dart';
import '../models/retry_attempt.dart';
import '../models/sms_request.dart';

/// Repository that mediates between services and the `sms_requests` +
/// `retry_attempts` tables.
class SmsRepository {
  SmsRepository(this._dbHelper, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final DatabaseHelper _dbHelper;
  final Uuid _uuid;

  late SmsQueries _sms;
  late RetryQueries _retry;

  /// Ensures the queries helpers are bound to an open database.
  Future<void> ensureOpen() async {
    final db = await _dbHelper.database();
    _sms = SmsQueries(db);
    _retry = RetryQueries(db);
  }

  /// Creates and persists a new SMS request.
  Future<SmsRequest> create({
    required String simId,
    required String recipient,
    required String message,
    int maxRetries = 3,
    SmsPriority priority = SmsPriority.normal,
    String? clientIp,
    Map<String, dynamic>? metadata,
  }) async {
    await ensureOpen();
    final now = DateTime.now().toUtc();
    final request = SmsRequest(
      id: _uuid.v4(),
      requestId: _uuid.v4(),
      simId: simId,
      recipient: recipient,
      message: message,
      messageLength: message.length,
      status: SmsStatus.pending,
      maxRetries: maxRetries,
      priority: priority,
      createdAt: now,
      clientIp: clientIp,
      metadata: metadata,
    );
    await _sms.insert(request);
    return request;
  }

  /// Returns a single request by id.
  Future<SmsRequest?> getById(String requestId) async {
    await ensureOpen();
    return _sms.getById(requestId);
  }

  /// Updates an existing request (status, retry counters, timestamps).
  Future<int> update(SmsRequest request) async {
    await ensureOpen();
    return _sms.update(request);
  }

  /// Cancels a pending/retrying request. Returns rows affected.
  Future<int> cancel(String requestId) async {
    await ensureOpen();
    return _sms.cancel(requestId, DateTime.now().toUtc());
  }

  /// Returns requests that still need processing.
  Future<List<SmsRequest>> pending() async {
    await ensureOpen();
    return _sms.getPendingOrRetrying();
  }

  /// Returns the most recent [limit] requests (dashboard).
  Future<List<SmsRequest>> recent({int limit = 10}) async {
    await ensureOpen();
    return _sms.getRecent(limit: limit);
  }

  /// Filtered & paginated log query.
  Future<List<SmsRequest>> query({
    int limit = 20,
    int offset = 0,
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    await ensureOpen();
    return _sms.query(
      limit: limit,
      offset: offset,
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Counts grouped by status name.
  Future<Map<String, int>> countsByStatus() async {
    await ensureOpen();
    return _sms.countsByStatus();
  }

  /// Total count matching the given filter (for pagination).
  Future<int> totalCount({
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    await ensureOpen();
    return _sms.totalCount(
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Records a retry attempt and updates the parent request counters.
  Future<RetryAttempt> recordRetry({
    required SmsRequest request,
    required bool success,
    String? errorMessage,
    String? errorCode,
    int? responseTimeMs,
  }) async {
    await ensureOpen();
    final attempt = RetryAttempt(
      id: _uuid.v4(),
      requestId: request.requestId,
      attemptNumber: request.currentRetryCount + 1,
      success: success,
      errorMessage: errorMessage,
      errorCode: errorCode,
      attemptedAt: DateTime.now().toUtc(),
      responseTimeMs: responseTimeMs,
    );
    await _retry.insert(attempt);

    request.currentRetryCount = attempt.attemptNumber;
    request.lastRetryAt = attempt.attemptedAt;
    if (success) {
      request.status = SmsStatus.sent;
      request.sentAt = attempt.attemptedAt;
      request.lastError = null;
    } else {
      request.lastError = errorMessage;
      request.status = request.currentRetryCount >= request.maxRetries
          ? SmsStatus.failed
          : SmsStatus.retrying;
      // Exponential backoff for the next attempt.
      final backoff = request.currentRetryCount == 0
          ? const Duration(seconds: 5)
          : Duration(seconds: 5 * (1 << request.currentRetryCount));
      request.nextRetryAt = attempt.attemptedAt.add(backoff);
    }
    await _sms.update(request);
    return attempt;
  }

  /// Returns the full retry history for a request.
  Future<List<RetryAttempt>> retryHistory(String requestId) async {
    await ensureOpen();
    return _retry.forRequest(requestId);
  }

  /// Average successful send time in ms.
  Future<int> averageResponseTimeMs() async {
    await ensureOpen();
    return _retry.averageResponseTimeMs();
  }

  /// Per-hour send activity for the dashboard chart.
  Future<List<({DateTime hour, int count})>> hourlyActivity({
    int hours = 24,
  }) async {
    await ensureOpen();
    return _sms.hourlyActivity(hours: hours);
  }

  /// Removes logs older than [age].
  Future<int> purgeOlderThan(Duration age) async {
    await ensureOpen();
    return _sms.deleteOlderThan(age);
  }

  /// Clears all SMS requests.
  Future<int> deleteAll() async {
    await ensureOpen();
    return _sms.deleteAll();
  }

  /// Serializes a request's full detail (with retries) for API responses.
  Future<Map<String, dynamic>> detailedJson(String requestId) async {
    final request = await getById(requestId);
    if (request == null) {
      throw StateError('Request $requestId not found');
    }
    final history = await retryHistory(requestId);
    final json = request.toApiResponseJson(detailed: true);
    json['retryHistory'] = history.map((a) => a.toApiJson()).toList();
    return json;
  }
}

/// JSON encode helper kept for potential future metadata export.
String encodeMetadata(Map<String, dynamic>? m) =>
    m == null ? '{}' : jsonEncode(m);
