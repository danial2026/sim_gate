/// A row in the `api_access_log` table, used for server analytics.
class ApiAccessLog {
  ApiAccessLog({
    required this.id,
    this.requestId,
    required this.clientIp,
    required this.endpoint,
    required this.method,
    required this.statusCode,
    this.responseTimeMs,
    this.requestBodySize,
    this.responseBodySize,
    required this.timestamp,
    this.errorMessage,
  });

  final String id;
  final String? requestId;
  final String clientIp;
  final String endpoint;
  final String method;
  final int statusCode;
  final int? responseTimeMs;
  final int? requestBodySize;
  final int? responseBodySize;
  final DateTime timestamp;
  final String? errorMessage;

  Map<String, dynamic> toMap() => {
    'id': id,
    'request_id': requestId,
    'client_ip': clientIp,
    'endpoint': endpoint,
    'method': method,
    'status_code': statusCode,
    'response_time_ms': responseTimeMs,
    'request_body_size': requestBodySize,
    'response_body_size': responseBodySize,
    'timestamp': timestamp.toIso8601String(),
    'error_message': errorMessage,
  };
}
