import 'dart:async';

/// Log severity levels supported by the [Logger].
enum LogLevel { debug, info, warning, error }

/// Component tags used to categorize log lines (matches the document).
enum LogComponent {
  sms,
  api,
  sim,
  server,
  auth,
  database,
  ui,
  retry,
  config,
}

extension LogComponentName on LogComponent {
  String get label => name.toUpperCase();
}

/// A single structured log entry.
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.component,
    required this.message,
    this.details,
    this.stackTrace,
    this.requestId,
  });

  final DateTime timestamp;
  final LogLevel level;
  final LogComponent component;
  final String message;
  final Map<String, dynamic>? details;
  final String? stackTrace;
  final String? requestId;

  /// Serializes the entry to JSON for persistence and export.
  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name.toUpperCase(),
        'component': component.label,
        'message': message,
        if (details != null) 'details': details,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (requestId != null) 'requestId': requestId,
      };

  @override
  String toString() =>
      '[${timestamp.toIso8601String()}] ${level.name.toUpperCase()} '
      '${component.label}: $message';
}

/// Abstract sink for log entries. Implemented by console, database, etc.
abstract interface class LogSink {
  void write(LogEntry entry);
}

/// A simple console [LogSink] used during tests and development.
class ConsoleLogSink implements LogSink {
  const ConsoleLogSink();
  @override
  void write(LogEntry entry) {
    // ignore: avoid_print
    print(entry.toString());
  }
}

/// Lightweight singleton-ish logger.
///
/// The logger routes entries through registered [LogSink]s. By default a
/// [ConsoleLogSink] is attached; the database service attaches a
/// database-backed sink at startup.
///
/// Respects a minimum [LogLevel] (configurable from Settings).
class Logger {
  Logger({LogLevel minLevel = LogLevel.info, List<LogSink>? sinks})
      : _minLevel = minLevel,
        _sinks = sinks ?? [const ConsoleLogSink()];

  LogLevel _minLevel;
  final List<LogSink> _sinks;

  /// Mutable minimum level. Lower-level entries are dropped.
  set minLevel(LogLevel level) => _minLevel = level;
  LogLevel get minLevel => _minLevel;

  void attachSink(LogSink sink) => _sinks.add(sink);
  void detachSink(LogSink sink) => _sinks.remove(sink);
  void clearSinks() => _sinks.clear();

  /// Records a log entry. Internal helper that fans out to sinks.
  void _record(LogEntry entry) {
    if (entry.level.index < _minLevel.index) return;
    for (final sink in _sinks) {
      sink.write(entry);
    }
  }

  void debug(
    LogComponent component,
    String message, {
    Map<String, dynamic>? details,
    String? requestId,
  }) =>
      _record(LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: LogLevel.debug,
        component: component,
        message: message,
        details: details,
        requestId: requestId,
      ));

  void info(
    LogComponent component,
    String message, {
    Map<String, dynamic>? details,
    String? requestId,
  }) =>
      _record(LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: LogLevel.info,
        component: component,
        message: message,
        details: details,
        requestId: requestId,
      ));

  void warning(
    LogComponent component,
    String message, {
    Map<String, dynamic>? details,
    String? stackTrace,
    String? requestId,
  }) =>
      _record(LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: LogLevel.warning,
        component: component,
        message: message,
        details: details,
        stackTrace: stackTrace,
        requestId: requestId,
      ));

  void error(
    LogComponent component,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
    String? requestId,
  }) =>
      _record(LogEntry(
        timestamp: DateTime.now().toUtc(),
        level: LogLevel.error,
        component: component,
        message: message,
        details: details,
        stackTrace: stackTrace?.toString() ?? error?.toString(),
        requestId: requestId,
      ));

  /// Convenience helper used by long-running services to log a Future result.
  Future<T> guard<T>(
    LogComponent component,
    String action,
    Future<T> Function() task, {
    String? requestId,
  }) async {
    try {
      info(component, action, requestId: requestId);
      final result = await task();
      info(component, '$action completed', requestId: requestId);
      return result;
    } catch (e, st) {
      error(
        component,
        '$action failed: $e',
        error: e,
        stackTrace: st,
        requestId: requestId,
      );
      rethrow;
    }
  }
}

/// Parses a stored string back into a [LogLevel].
LogLevel parseLogLevel(String value) {
  return LogLevel.values.firstWhere(
    (l) => l.name == value.toLowerCase(),
    orElse: () => LogLevel.info,
  );
}

/// Default minimum level used when no preference is stored.
LogLevel get defaultLogLevel => LogLevel.info;
