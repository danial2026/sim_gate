import '../utils/logger.dart';

/// A single application log entry persisted in the `app_logs` table.
class AppLog {
  AppLog({
    required this.id,
    required this.level,
    required this.component,
    required this.message,
    this.details,
    required this.timestamp,
    this.stackTrace,
  });

  final String id;
  final LogLevel level;
  final LogComponent component;
  final String message;
  final Map<String, dynamic>? details;
  final DateTime timestamp;
  final String? stackTrace;

  factory AppLog.fromMap(Map<String, dynamic> map) {
    return AppLog(
      id: map['id'] as String,
      level: parseLogLevel((map['log_level'] as String?) ?? 'INFO'),
      component: _parseComponent(map['component'] as String),
      message: map['message'] as String,
      details: map['details'] == null
          ? null
          : Map<String, dynamic>.from(map['details'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String).toUtc(),
      stackTrace: map['stack_trace'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'log_level': level.name.toUpperCase(),
        'component': component.label,
        'message': message,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
        'stack_trace': stackTrace,
      };

  static LogComponent _parseComponent(String value) {
    return LogComponent.values.firstWhere(
      (c) => c.label == value.toUpperCase(),
      orElse: () => LogComponent.server,
    );
  }
}
