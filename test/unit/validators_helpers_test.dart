import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/utils/logger.dart';
import 'package:sim_gate/utils/validators.dart';
import 'package:sim_gate/utils/helpers.dart';

void main() {
  group('PhoneNumberValidator', () {
    test('accepts valid E.164 numbers', () {
      expect(PhoneNumberValidator.isValid('+1234567890'), isTrue);
      expect(PhoneNumberValidator.isValid('1234567'), isTrue);
      expect(PhoneNumberValidator.isValid('+447700900123'), isTrue);
    });

    test('rejects invalid numbers', () {
      expect(PhoneNumberValidator.isValid(null), isFalse);
      expect(PhoneNumberValidator.isValid(''), isFalse);
      expect(PhoneNumberValidator.isValid('abc'), isFalse);
      expect(PhoneNumberValidator.isValid('123'), isFalse);
      expect(PhoneNumberValidator.isValid('+1(234)567'), isFalse);
      expect(PhoneNumberValidator.isValid('1234567890123456'), isFalse);
    });

    test('masks numbers for display', () {
      expect(PhoneNumberValidator.mask('+1234567890'), '+123****7890');
      expect(PhoneNumberValidator.mask('12345'), '12****45');
    });
  });

  group('PortValidator', () {
    test('accepts the documented range', () {
      expect(PortValidator.isValid(1024), isTrue);
      expect(PortValidator.isValid(3000), isTrue);
      expect(PortValidator.isValid(65535), isTrue);
    });

    test('rejects out-of-range and null', () {
      expect(PortValidator.isValid(null), isFalse);
      expect(PortValidator.isValid(0), isFalse);
      expect(PortValidator.isValid(80), isFalse);
      expect(PortValidator.isValid(65536), isFalse);
    });
  });

  group('MessageValidator', () {
    test('validates non-empty short messages', () {
      expect(MessageValidator.isValid('hello'), isTrue);
      expect(MessageValidator.isValid(''), isFalse);
      expect(MessageValidator.isValid(null), isFalse);
      expect(MessageValidator.isValid('   '), isFalse);
    });

    test('caps at 1600 chars', () {
      expect(MessageValidator.isValid('x' * 1600), isTrue);
      expect(MessageValidator.isValid('x' * 1601), isFalse);
    });

    test('computes segment count', () {
      expect(MessageValidator.segmentCount(''), 0);
      expect(MessageValidator.segmentCount('x' * 160), 1);
      expect(MessageValidator.segmentCount('x' * 161), 2);
    });
  });

  group('IpValidator', () {
    test('accepts valid IPv4 and wildcards', () {
      expect(IpValidator.isValid('0.0.0.0'), isTrue);
      expect(IpValidator.isValid('localhost'), isTrue);
      expect(IpValidator.isValid('192.168.1.1'), isTrue);
      expect(IpValidator.isValid('255.255.255.255'), isTrue);
    });

    test('rejects malformed IPs', () {
      expect(IpValidator.isValid(null), isFalse);
      expect(IpValidator.isValid(''), isFalse);
      expect(IpValidator.isValid('192.168.1'), isFalse);
      expect(IpValidator.isValid('192.168.1.999'), isFalse);
      expect(IpValidator.isValid('abc.def.ghi.jkl'), isFalse);
    });
  });

  group('Formatters', () {
    test('formats durations as HH:MM:SS', () {
      expect(Formatters.formatDuration(const Duration(hours: 2, minutes: 30, seconds: 45)),
          '02:30:45');
      expect(Formatters.formatDuration(Duration.zero), '00:00:00');
    });

    test('formats relative times', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      expect(
          Formatters.formatRelative(now.subtract(const Duration(seconds: 30)),
              now: now),
          '30s ago');
      expect(
          Formatters.formatRelative(now.subtract(const Duration(minutes: 5)),
              now: now),
          '5m ago');
      expect(
          Formatters.formatRelative(now.subtract(const Duration(hours: 3)),
              now: now),
          '3h ago');
      expect(
          Formatters.formatRelative(now.subtract(const Duration(days: 2)),
              now: now),
          '2d ago');
    });

    test('formats byte sizes', () {
      expect(Formatters.formatBytes(512), '512 B');
      expect(Formatters.formatBytes(2048), '2.0 KB');
      expect(Formatters.formatBytes(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('Logger', () {
    test('respects the minimum level', () {
      final entries = <LogEntry>[];
      final logger = Logger(
        minLevel: LogLevel.warning,
        sinks: [_CollectingSink(entries)],
      );
      logger.debug(LogComponent.sms, 'debug');
      logger.info(LogComponent.sms, 'info');
      logger.warning(LogComponent.sms, 'warn');
      logger.error(LogComponent.sms, 'err');
      expect(entries.map((e) => e.level).toList(),
          [LogLevel.warning, LogLevel.error]);
    });

    test('serializes to JSON with request id', () {
      final entry = LogEntry(
        timestamp: DateTime.utc(2026, 1, 1),
        level: LogLevel.error,
        component: LogComponent.sms,
        message: 'boom',
        requestId: 'req-1',
      );
      final json = entry.toJson();
      expect(json['level'], 'ERROR');
      expect(json['component'], 'SMS');
      expect(json['requestId'], 'req-1');
    });
  });
}

/// Test sink that collects entries into a list.
class _CollectingSink implements LogSink {
  _CollectingSink(this.entries);
  final List<LogEntry> entries;

  @override
  void write(LogEntry entry) => entries.add(entry);
}
