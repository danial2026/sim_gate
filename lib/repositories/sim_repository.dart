import '../database/database_helper.dart';
import '../database/queries/sim_queries.dart';
import '../models/sim_card.dart';

/// Repository mediating between [SimService] and the `sim_cards` table.
class SimRepository {
  SimRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;
  SimQueries? _queries;

  Future<SimQueries> _q() async {
    _queries ??= SimQueries(await _dbHelper.database());
    return _queries!;
  }

  /// Upserts a list of detected SIMs and prunes missing entries.
  Future<void> syncAll(List<SimCard> sims) async {
    final q = await _q();
    await q.upsertAll(sims);
    await q.purgeMissing(sims.map((s) => s.simId).toSet());
  }

  /// Returns all known SIMs ordered by slot.
  Future<List<SimCard>> getAll() async {
    final q = await _q();
    return q.getAll();
  }

  /// Returns only active SIMs.
  Future<List<SimCard>> getActive() async {
    final q = await _q();
    return q.getActive();
  }

  /// Toggles the active flag for a SIM. Returns rows affected.
  Future<int> setActive(String simId, bool active) async {
    final q = await _q();
    return q.setActive(simId, active);
  }

  /// Number of active SIMs.
  Future<int> activeCount() async {
    final q = await _q();
    return q.activeCount();
  }

  /// Total number of SIMs.
  Future<int> totalCount() async {
    final q = await _q();
    return q.totalCount();
  }

  /// Clears the SIM table (used during tests).
  Future<int> deleteAll() async {
    final q = await _q();
    return q.deleteAll();
  }
}
