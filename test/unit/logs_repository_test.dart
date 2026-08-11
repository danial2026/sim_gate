import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';
import 'package:sim_gate/models/api_access_log.dart';
import 'package:sim_gate/models/app_log.dart';
import 'package:sim_gate/repositories/logs_repository.dart';
import 'package:sim_gate/utils/logger.dart';

import '../test_harness.dart';

void main() {
  late TestHarness harness;
  late LogsRepository repo;

  setUp(() async {
    harness = await TestHarness.create();
    repo = LogsRepository(getIt<DatabaseHelper>());
  });

  tearDown(() => harness.dispose());

  group('LogsRepository', () {
    test('inserts and queries app logs', () async {
      await repo.insert(
        AppLog(
          id: '1',
          level: LogLevel.error,
          component: LogComponent.sms,
          message: 'send failed',
          timestamp: DateTime.utc(2026, 1, 1),
        ),
      );
      await repo.insert(
        AppLog(
          id: '2',
          level: LogLevel.info,
          component: LogComponent.server,
          message: 'started',
          timestamp: DateTime.utc(2026, 1, 2),
        ),
      );
      final all = await repo.query();
      expect(all.length, 2);

      final filtered = await repo.query(level: 'error');
      expect(filtered.length, 1);
      expect(filtered.first.component, LogComponent.sms);

      final byComponent = await repo.query(component: 'server');
      expect(byComponent.length, 1);
    });

    test('search filters by message text', () async {
      await repo.insert(
        AppLog(
          id: '1',
          level: LogLevel.info,
          component: LogComponent.config,
          message: 'Port updated to 9000',
          timestamp: DateTime.utc(2026, 1, 1),
        ),
      );
      final found = await repo.query(searchQuery: '9000');
      expect(found.length, 1);
      final missing = await repo.query(searchQuery: 'nope');
      expect(missing, isEmpty);
    });

    test('deleteOlderThan prunes old rows', () async {
      await repo.insert(
        AppLog(
          id: 'old',
          level: LogLevel.info,
          component: LogComponent.ui,
          message: 'old',
          timestamp: DateTime.now().toUtc().subtract(const Duration(days: 60)),
        ),
      );
      await repo.insert(
        AppLog(
          id: 'new',
          level: LogLevel.info,
          component: LogComponent.ui,
          message: 'new',
          timestamp: DateTime.now().toUtc(),
        ),
      );
      final removed = await repo.purgeOlderThan(const Duration(days: 30));
      expect(removed, 1);
      expect((await repo.query()).single.message, 'new');
    });

    test('trim caps the table size', () async {
      for (var i = 0; i < 10; i++) {
        await repo.insert(
          AppLog(
            id: '$i',
            level: LogLevel.debug,
            component: LogComponent.database,
            message: 'log $i',
            timestamp: DateTime.utc(2026, 1, 1 + i),
          ),
        );
      }
      final removed = await repo.trim(4);
      expect(removed, 6);
      expect((await repo.query()).length, 4);
    });

    test('access logs track clients and totals', () async {
      await repo.recordAccess(
        ApiAccessLog(
          id: 'a1',
          clientIp: '192.168.1.5',
          endpoint: '/api/health',
          method: 'GET',
          statusCode: 200,
          timestamp: DateTime.now().toUtc(),
        ),
      );
      await repo.recordAccess(
        ApiAccessLog(
          id: 'a2',
          clientIp: '192.168.1.5',
          endpoint: '/api/sms/send',
          method: 'POST',
          statusCode: 201,
          timestamp: DateTime.now().toUtc(),
        ),
      );
      expect(await repo.totalApiRequests(), 2);
      expect(await repo.connectedClients(), 1);
    });
  });
}
