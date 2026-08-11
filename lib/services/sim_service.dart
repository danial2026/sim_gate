import '../models/sim_card.dart';
import '../repositories/sim_repository.dart';
import '../utils/logger.dart';
import 'platform_channel_service.dart';

/// Detects SIM cards, persists them, and manages active/inactive state.
class SimService {
  SimService({
    required SimRepository repository,
    required PlatformChannelService platform,
    Logger? logger,
  }) : _repo = repository,
       _platform = platform,
       _logger = logger ?? Logger();

  final SimRepository _repo;
  final PlatformChannelService _platform;
  final Logger _logger;

  /// Refreshes the SIM list from the platform and persists it.
  Future<List<SimCard>> refresh() async {
    final sims = await _platform.detectSims();
    if (sims.isEmpty) {
      _logger.warning(LogComponent.sim, 'No SIM cards detected');
      return const [];
    }
    await _repo.syncAll(sims);
    _logger.info(
      LogComponent.sim,
      'SIM list refreshed',
      details: {'count': sims.length},
    );
    return _repo.getAll();
  }

  /// Returns all known SIMs.
  Future<List<SimCard>> getAll() => _repo.getAll();

  /// Returns only active SIMs.
  Future<List<SimCard>> getActive() => _repo.getActive();

  /// Toggles a SIM active. Enforces at least one active SIM when [requireOne]
  /// is true; returns the resulting active state, or throws if disallowed.
  Future<bool> toggle(
    String simId,
    bool activate, {
    bool requireOne = true,
  }) async {
    if (!activate && requireOne) {
      final active = await _repo.getActive();
      if (active.length <= 1) {
        _logger.warning(
          LogComponent.sim,
          'Refusing to deactivate last active SIM $simId',
        );
        throw StateError('At least one SIM must remain active');
      }
    }
    await _repo.setActive(simId, activate);
    _logger.info(
      LogComponent.sim,
      'SIM toggled',
      details: {'simId': simId, 'active': activate},
    );
    return activate;
  }

  /// Sets a SIM active by id.
  Future<int> setActive(String simId, bool active) =>
      _repo.setActive(simId, active);

  /// Number of active SIMs.
  Future<int> activeCount() => _repo.activeCount();

  /// Total number of SIMs.
  Future<int> totalCount() => _repo.totalCount();
}
