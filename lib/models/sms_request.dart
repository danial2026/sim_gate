/// Status values tracked for an SMS request throughout its lifecycle.
enum SmsStatus {
  pending,
  retrying,
  sent,
  failed,
  cancelled;

  /// Parses a status string received from storage/API.
  static SmsStatus fromName(String name) {
    return SmsStatus.values.firstWhere(
      (s) => s.name == name.toLowerCase(),
      orElse: () => SmsStatus.pending,
    );
  }

  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Priority bucket used for send ordering and retry scheduling.
enum SmsPriority { low, normal, high }

/// A single SMS send request tracked by the gateway.
///
/// Mirrors the `sms_requests` SQLite table defined in the project document.
class SmsRequest {
  SmsRequest({
    required this.id,
    required this.requestId,
    required this.simId,
    required this.recipient,
    required this.message,
    required this.messageLength,
    required this.status,
    this.maxRetries = 3,
    this.currentRetryCount = 0,
    this.lastError,
    this.priority = SmsPriority.normal,
    required this.createdAt,
    this.sentAt,
    this.cancelledAt,
    this.lastRetryAt,
    this.nextRetryAt,
    this.expiresAt,
    this.clientIp,
    this.metadata,
  });

  final String id;
  final String requestId;
  final String simId;
  final String recipient;
  final String message;
  final int messageLength;
  SmsStatus status;
  final int maxRetries;
  int currentRetryCount;
  String? lastError;
  final SmsPriority priority;
  final DateTime createdAt;
  DateTime? sentAt;
  DateTime? cancelledAt;
  DateTime? lastRetryAt;
  DateTime? nextRetryAt;
  DateTime? expiresAt;
  final String? clientIp;
  Map<String, dynamic>? metadata;

  /// Builds an [SmsRequest] from a database row map.
  factory SmsRequest.fromMap(Map<String, dynamic> map) {
    return SmsRequest(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      simId: map['sim_id'] as String,
      recipient: map['recipient'] as String,
      message: map['message'] as String,
      messageLength: map['message_length'] as int,
      status: SmsStatus.fromName(map['status'] as String),
      maxRetries: (map['max_retries'] as int?) ?? 3,
      currentRetryCount: (map['current_retry_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
      priority: _parsePriority(map['priority'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
      sentAt: _parseDate(map['sent_at']),
      cancelledAt: _parseDate(map['cancelled_at']),
      lastRetryAt: _parseDate(map['last_retry_at']),
      nextRetryAt: _parseDate(map['next_retry_at']),
      expiresAt: _parseDate(map['expires_at']),
      clientIp: map['client_ip'] as String?,
      metadata: map['metadata'] == null
          ? null
          : Map<String, dynamic>.from(map['metadata'] as Map),
    );
  }

  static SmsPriority _parsePriority(String? value) {
    if (value == null) return SmsPriority.normal;
    return SmsPriority.values.firstWhere(
      (p) => p.name == value.toLowerCase(),
      orElse: () => SmsPriority.normal,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.parse(value).toUtc();
    return null;
  }

  /// Serializes the request for persistence or API responses.
  Map<String, dynamic> toMap() => {
    'id': id,
    'request_id': requestId,
    'sim_id': simId,
    'recipient': recipient,
    'message': message,
    'message_length': messageLength,
    'status': status.name,
    'max_retries': maxRetries,
    'current_retry_count': currentRetryCount,
    'last_error': lastError,
    'priority': priority.name,
    'created_at': createdAt.toIso8601String(),
    'sent_at': sentAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'last_retry_at': lastRetryAt?.toIso8601String(),
    'next_retry_at': nextRetryAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'client_ip': clientIp,
    'metadata': metadata,
  };

  /// API-style JSON representation (without the full message body).
  Map<String, dynamic> toApiResponseJson({bool detailed = false}) {
    final base = <String, dynamic>{
      'requestId': requestId,
      'status': status.name,
      'simId': simId,
      'recipient': recipient,
      'messageLength': messageLength,
      'createdAt': createdAt.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'retryCount': currentRetryCount,
      'maxRetries': maxRetries,
      'lastError': lastError,
    };
    if (detailed) base['message'] = message;
    return base;
  }

  /// Returns a short preview used in log lists.
  String get messagePreview =>
      message.length > 50 ? '${message.substring(0, 50)}...' : message;

  /// Returns `true` when the request can still be cancelled.
  bool get isCancellable =>
      status == SmsStatus.pending || status == SmsStatus.retrying;

  /// Returns `true` when the request can be retried.
  bool get canRetry =>
      status == SmsStatus.failed && currentRetryCount < maxRetries;
}
