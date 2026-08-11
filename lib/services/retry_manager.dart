import 'dart:async';

import '../models/sms_request.dart';
import '../repositories/sms_repository.dart';
import '../utils/logger.dart';
import 'sms_service.dart';

/// Periodically drains pending/retrying SMS requests and retries them with
/// exponential backoff. Runs as a background timer inside the app process.
class RetryManager {
  RetryManager({
    required SmsService smsService,
    required SmsRepository repository,
    Duration interval = const Duration(seconds: 5),
    Logger? logger,
  })  : _sms = smsService,
        _repo = repository,
        _interval = interval,
        _logger = logger ?? Logger();

  final SmsService _sms;
  final SmsRepository _repo;
  final Duration _interval;
  final Logger _logger;

  Timer? _timer;
  bool _running = false;

  /// Whether the manager is currently processing.
  bool get isRunning => _timer != null;

  /// Starts the retry loop. Calling while already running is a no-op.
  void start() {
    if (_timer != null) return;
    _logger.info(LogComponent.retry, 'Retry manager started',
        details: {'intervalMs': _interval.inMilliseconds});
    _timer = Timer.periodic(_interval, (_) => _tick());
    // Fire an immediate tick so the first pass doesn't wait an interval.
    _tick();
  }

  /// Stops the retry loop.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _logger.info(LogComponent.retry, 'Retry manager stopped');
  }

  /// A single pass over pending requests.
  Future<int> tick() async => _tick();

  Future<int> _tick() async {
    if (_running) return 0;
    _running = true;
    try {
      final pending = await _repo.pending();
      if (pending.isEmpty) return 0;
      final now = DateTime.now().toUtc();
      var processed = 0;
      for (final request in pending) {
        if (request.status == SmsStatus.retrying &&
            request.nextRetryAt != null &&
            now.isBefore(request.nextRetryAt!)) {
          // Backoff window not elapsed yet.
          continue;
        }
        await _sms.attemptSend(request);
        processed++;
      }
      if (processed > 0) {
        _logger.info(LogComponent.retry, 'Retry pass complete',
            details: {'processed': processed});
      }
      return processed;
    } catch (e, st) {
      _logger.error(LogComponent.retry, 'Retry pass failed',
          error: e, stackTrace: st);
      rethrow;
    } finally {
      _running = false;
    }
  }
}
