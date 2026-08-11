import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/repositories/sim_repository.dart';

import '../test_harness.dart';

SimCard sim(int slot, {bool active = true, int signal = 3}) {
  return SimCard(
    simId: 'sim-$slot',
    slotNumber: slot,
    name: 'SIM $slot',
    phoneNumber: '+123400000$slot',
    carrier: 'Carrier $slot',
    signalStrength: signal,
    networkType: NetworkType.fourG,
    isActive: active,
  );
}

void main() {
  late TestHarness harness;
  late SimRepository repo;

  setUp(() async {
    harness = await TestHarness.create();
    repo = SimRepository(getIt<DatabaseHelper>());
  });

  tearDown(() => harness.dispose());

  group('SimRepository', () {
    test('syncAll persists sims and prunes missing', () async {
      await repo.syncAll([sim(0), sim(1)]);
      var all = await repo.getAll();
      expect(all.length, 2);

      // One SIM disappears; syncAll must prune it.
      await repo.syncAll([sim(0)]);
      all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.simId, 'sim-0');
    });

    test('getActive returns only active sims', () async {
      await repo.syncAll([sim(0), sim(1, active: false)]);
      final active = await repo.getActive();
      expect(active.length, 1);
      expect(active.first.slotNumber, 0);
    });

    test('setActive toggles state', () async {
      await repo.syncAll([sim(0)]);
      await repo.setActive('sim-0', false);
      expect(await repo.activeCount(), 0);
      await repo.setActive('sim-0', true);
      expect(await repo.activeCount(), 1);
    });

    test('counts match the table contents', () async {
      await repo.syncAll([sim(0), sim(1), sim(2, active: false)]);
      expect(await repo.totalCount(), 3);
      expect(await repo.activeCount(), 2);
    });

    test('upserts preserve signal/network details', () async {
      await repo.syncAll([sim(0, signal: 1)]);
      await repo.syncAll([sim(0, signal: 4)]);
      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.signalStrength, 4);
    });
  });
}
