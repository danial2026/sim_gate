import '../utils/logger.dart';
import 'platform_channel_service.dart';

/// Controls the Android foreground service that keeps the gateway process
/// alive while the phone is locked or the app is backgrounded.
///
/// The HTTP server itself runs in the Dart isolate; the native service only
/// guarantees the process is never reaped (by Android or Samsung's battery
/// management) and holds a wake lock so the CPU can serve requests with the
/// screen off. Start it whenever the API server is running.
class BackgroundService {
  BackgroundService({required PlatformChannelService platform, Logger? logger})
    : _platform = platform,
      _logger = logger ?? Logger();

  final PlatformChannelService _platform;
  final Logger _logger;

  bool _active = false;

  /// Whether [start] was requested (the native service may take a moment).
  bool get isActive => _active;

  /// Starts the foreground service. Safe to call multiple times.
  Future<void> start() async {
    _active = true;
    try {
      await _platform.startForegroundService();
      _logger.info(LogComponent.server, 'Foreground service started');
    } catch (e) {
      _logger.error(
        LogComponent.server,
        'Failed to start foreground service',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  /// Stops the foreground service. Safe to call multiple times.
  Future<void> stop() async {
    _active = false;
    try {
      await _platform.stopForegroundService();
      _logger.info(LogComponent.server, 'Foreground service stopped');
    } catch (e) {
      _logger.error(
        LogComponent.server,
        'Failed to stop foreground service',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  /// Whether the app is exempt from battery optimization (Doze / Samsung
  /// app-sleeping). False means the gateway may be killed when locked.
  Future<bool> isBatteryOptimizationIgnored() {
    return _platform.isBatteryOptimizationIgnored();
  }

  /// Shows the system dialog to whitelist SimGate from battery optimization.
  Future<void> requestBatteryOptimizationExemption() async {
    await _platform.requestIgnoreBatteryOptimizations();
  }

  /// Opens the battery settings page (Samsung Device Care when available).
  Future<bool> openBatterySettings() {
    return _platform.openAppBatterySettings();
  }
}
