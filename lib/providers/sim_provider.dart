import 'package:flutter/foundation.dart';

import '../models/sim_card.dart';
import '../services/sim_service.dart';
import '../utils/logger.dart';

/// Holds the list of SIM cards and exposes refresh/toggle operations.
class SimProvider extends ChangeNotifier {
  SimProvider({required this.simService, Logger? logger})
    : _logger = logger ?? Logger();

  final SimService simService;
  final Logger _logger;

  List<SimCard> _sims = const [];
  List<SimCard> get sims => _sims;
  List<SimCard> get activeSims => _sims.where((s) => s.isActive).toList();

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  /// Refreshes the SIM list from the platform.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _sims = await simService.refresh();
    } catch (e, st) {
      _logger.error(
        LogComponent.sim,
        'Refresh failed',
        error: e,
        stackTrace: st,
      );
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads cached SIMs from the database (no platform call).
  Future<void> loadCached() async {
    _sims = await simService.getAll();
    notifyListeners();
  }

  /// Toggles a SIM active. Returns whether it was activated.
  Future<bool> toggle(SimCard sim) async {
    try {
      final newState = !sim.isActive;
      await simService.toggle(sim.simId, newState);
      await loadCached();
      return newState;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Sets a SIM active by id.
  Future<void> setActive(String simId, bool active) async {
    await simService.setActive(simId, active);
    await loadCached();
  }
}
