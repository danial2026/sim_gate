import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/configuration.dart';
import '../services/background_service.dart';
import '../services/retry_manager.dart';
import '../server/http_server.dart';
import '../utils/logger.dart';

/// Owns the [HttpServerService] and [RetryManager] lifecycle.
///
/// Notifies the UI whenever the server transitions between
/// [ServerState]s and exposes the current uptime.
class ServerProvider extends ChangeNotifier {
  ServerProvider({
    required this.httpServer,
    required this.retryManager,
    BackgroundService? backgroundService,
    Logger? logger,
  }) : _backgroundService = backgroundService,
       _logger = logger ?? Logger() {
    _subscription = httpServer.stateStream.listen(_onState);
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (httpServer.isRunning) notifyListeners();
    });
  }

  final HttpServerService httpServer;
  final RetryManager retryManager;
  final BackgroundService? _backgroundService;
  final Logger _logger;

  late final StreamSubscription<ServerState> _subscription;
  late final Timer _uptimeTimer;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  /// Starts the server + retry manager using [config].
  Future<String> start(AppConfiguration config) async {
    _isBusy = true;
    notifyListeners();
    try {
      final url = await httpServer.start(
        ip: config.serverIp,
        port: config.serverPort,
      );
      retryManager.start();
      // Keep the process alive when the phone locks / the app is backgrounded.
      await _backgroundService?.start();
      return url;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Stops everything.
  Future<void> stop() async {
    _isBusy = true;
    notifyListeners();
    try {
      retryManager.stop();
      await httpServer.stop();
      await _backgroundService?.stop();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Current uptime as a [Duration].
  Duration get uptime {
    final start = httpServer.startTime;
    if (start == null || !httpServer.isRunning) return Duration.zero;
    return DateTime.now().toUtc().difference(start);
  }

  ServerState get state => httpServer.state;
  bool get isRunning => httpServer.isRunning;

  void _onState(ServerState state) {
    _logger.info(LogComponent.server, 'State -> ${state.name}');
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _uptimeTimer.cancel();
    super.dispose();
  }
}
