import 'package:sqflite/sqflite.dart';

import '../../models/sim_card.dart';

/// SQL access helpers for the `sim_cards` table.
class SimQueries {
  SimQueries(this._db);
  final Database _db;

  static const String _table = 'sim_cards';

  /// Upserts a SIM card (insert or replace by sim_id).
  Future<void> upsert(SimCard sim) async {
    final map = sim.toMap();
    map['id'] = sim.simId;
    await _db.insert(_table, map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Upserts many SIMs in a single batch.
  Future<void> upsertAll(List<SimCard> sims) async {
    final batch = _db.batch();
    for (final sim in sims) {
      final map = sim.toMap();
      map['id'] = sim.simId;
      batch.insert(_table, map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Returns all SIMs sorted by slot number.
  Future<List<SimCard>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'slot_number ASC');
    return rows.map(SimCard.fromMap).toList();
  }

  /// Returns only active SIMs.
  Future<List<SimCard>> getActive() async {
    final rows = await _db.query(
      _table,
      where: 'is_active = 1',
      orderBy: 'slot_number ASC',
    );
    return rows.map(SimCard.fromMap).toList();
  }

  /// Sets the active flag for a SIM by [simId].
  Future<int> setActive(String simId, bool active) {
    return _db.update(
      _table,
      {'is_active': active ? 1 : 0},
      where: 'sim_id = ?',
      whereArgs: [simId],
    );
  }

  /// Counts active SIMs.
  Future<int> activeCount() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE is_active = 1',
    );
    return (rows.first['count'] as num).toInt();
  }

  /// Total SIM count.
  Future<int> totalCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) as count FROM $_table');
    return (rows.first['count'] as num).toInt();
  }

  /// Removes SIMs that are no longer present (by sim_id set).
  Future<int> purgeMissing(Set<String> knownSimIds) async {
    if (knownSimIds.isEmpty) return _db.delete(_table);
    final placeholders = List.filled(knownSimIds.length, '?').join(',');
    return _db.delete(
      _table,
      where: 'sim_id NOT IN ($placeholders)',
      whereArgs: knownSimIds.toList(),
    );
  }

  Future<int> deleteAll() => _db.delete(_table);
}
