/// Central registry of HTTP API endpoint paths used by the embedded server.
///
/// Keeping paths here avoids string duplication between the shelf handlers,
/// the route table, and the tests.
class ApiEndpoints {
  ApiEndpoints._();

  static const String base = '/api';

  // GET endpoints -------------------------------------------------------------
  static const String health = '/api/health';
  static const String activeSims = '/api/sims/active';
  static const String smsStatus = '/api/sms/status';
  static const String smsLogs = '/api/sms/logs';
  static const String serverInfo = '/api/server/info';
  static const String serverToken = '/api/server/token';

  // POST endpoints ------------------------------------------------------------
  static const String smsSend = '/api/sms/send';
  static const String smsCancel = '/api/sms/cancel';
  static const String tokenRegenerate = '/api/token/regenerate';
  static const String simsActivate = '/api/sims/activate';

  // PUT endpoints -------------------------------------------------------------
  static const String configPort = '/api/config/port';
  static const String configIp = '/api/config/ip';
  static const String logsRetention = '/api/logs/retention';
}
