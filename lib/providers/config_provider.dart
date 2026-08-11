import 'package:flutter/foundation.dart';

import '../models/configuration.dart';
import '../services/config_service.dart';
import '../services/token_service.dart';
import '../utils/logger.dart';

/// Holds the [AppConfiguration] and notifies listeners on changes.
class ConfigProvider extends ChangeNotifier {
  ConfigProvider({
    required this.configService,
    required this.tokenService,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final ConfigService configService;
  final TokenService tokenService;
  final Logger _logger;

  AppConfiguration _config = AppConfiguration();
  AppConfiguration get config => _config;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Loads the configuration and ensures a token exists.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _config = configService.load();
      await tokenService.ensureToken();
      _config = configService.load();
      _logger.setMinLevelString(_config.logLevel);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the IP and persists it.
  Future<void> updateIp(String ip) async {
    await configService.updateIp(ip);
    _config = configService.load();
    notifyListeners();
  }

  /// Updates the port and persists it.
  Future<void> updatePort(int port) async {
    await configService.updatePort(port);
    _config = configService.load();
    notifyListeners();
  }

  /// Updates the auto-start flag.
  Future<void> updateAutoStart(bool value) async {
    await configService.updateAutoStart(value);
    _config = configService.load();
    notifyListeners();
  }

  /// Updates the theme mode.
  Future<void> updateTheme(AppThemeMode mode) async {
    final updated = _config.copyWith(appTheme: mode);
    await configService.save(updated);
    _config = configService.load();
    notifyListeners();
  }

  /// Updates log settings.
  Future<void> updateLogSettings({
    required String level,
    required int retentionDays,
    required int maxEntries,
  }) async {
    final updated = _config.copyWith(
      logLevel: level,
      logRetentionDays: retentionDays,
      maxLogEntries: maxEntries,
    );
    await configService.save(updated);
    _config = configService.load();
    _logger.setMinLevelString(level);
    notifyListeners();
  }

  /// Updates the active SIM id list.
  Future<void> updateActiveSims(List<String> ids) async {
    await configService.updateActiveSims(ids);
    _config = configService.load();
    notifyListeners();
  }

  /// Regenerates the access token.
  Future<void> regenerateToken() async {
    await tokenService.regenerate();
    _config = configService.load();
    notifyListeners();
  }
}
