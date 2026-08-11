import '../models/configuration.dart';
import '../repositories/config_repository.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';

/// Application-level configuration service.
///
/// Wraps [ConfigRepository] with validation and change notifications, used by
/// the settings page and the API PUT /config endpoints.
class ConfigService {
  ConfigService({
    required ConfigRepository repository,
    Logger? logger,
  })  : _repo = repository,
        _logger = logger ?? Logger();

  final ConfigRepository _repo;
  final Logger _logger;

  /// Loads the current configuration.
  AppConfiguration load() => _repo.load();

  /// Updates the listening port after validating the range.
  ///
  /// Throws [ArgumentError] when the port is out of range.
  Future<void> updatePort(int port) async {
    if (!PortValidator.isValid(port)) {
      throw ArgumentError(PortValidator.errorMessage(port) ?? 'Invalid port');
    }
    await _repo.savePort(port);
    _logger.info(LogComponent.config, 'Port updated',
        details: {'port': port});
  }

  /// Updates the listening IP after validating format.
  Future<void> updateIp(String ip) async {
    if (!IpValidator.isValid(ip)) {
      throw ArgumentError('Invalid IP address: $ip');
    }
    await _repo.saveIp(ip);
    _logger.info(LogComponent.config, 'IP updated', details: {'ip': ip});
  }

  /// Updates the auto-start flag.
  Future<void> updateAutoStart(bool value) async {
    await _repo.saveAutoStart(value);
    _logger.info(LogComponent.config, 'Auto-start updated',
        details: {'value': value});
  }

  /// Updates the active SIM id list.
  Future<void> updateActiveSims(List<String> ids) async {
    await _repo.saveActiveSims(ids);
    _logger.info(LogComponent.config, 'Active SIMs updated',
        details: {'count': ids.length});
  }

  /// Persists the full configuration object.
  Future<void> save(AppConfiguration config) => _repo.save(config);
}
