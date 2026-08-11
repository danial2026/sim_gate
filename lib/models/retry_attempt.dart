/// A single retry attempt for an SMS request, persisted in `retry_attempts`.
class RetryAttempt {
  RetryAttempt({
    required this.id,
    required this.requestId,
    required this.attemptNumber,
    required this.success,
    this.errorMessage,
    this.errorCode,
    required this.attemptedAt,
    this.responseTimeMs,
  });

  final String id;
  final String requestId;
  final int attemptNumber;
  final bool success;
  final String? errorMessage;
  final String? errorCode;
  final DateTime attemptedAt;
  final int? responseTimeMs;

  factory RetryAttempt.fromMap(Map<String, dynamic> map) {
    return RetryAttempt(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      attemptNumber: (map['attempt_number'] as num).toInt(),
      success: (map['status'] as String) == 'success',
      errorMessage: map['error_message'] as String?,
      errorCode: map['error_code'] as String?,
      attemptedAt: DateTime.parse(map['attempted_at'] as String).toUtc(),
      responseTimeMs: (map['response_time_ms'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'request_id': requestId,
        'attempt_number': attemptNumber,
        'status': success ? 'success' : 'failed',
        'error_message': errorMessage,
        'error_code': errorCode,
        'attempted_at': attemptedAt.toIso8601String(),
        'response_time_ms': responseTimeMs,
      };

  /// API-style JSON representation.
  Map<String, dynamic> toApiJson() => {
        'attempt': attemptNumber,
        'status': success ? 'sent' : 'failed',
        'timestamp': attemptedAt.toIso8601String(),
        'message': success ? 'SMS sent successfully' : (errorMessage ?? 'Failed'),
      };
}
