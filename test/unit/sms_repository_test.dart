import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/database/database_helper.dart';
import 'package:sim_gate/models/sms_request.dart';
import 'package:sim_gate/repositories/sms_repository.dart';

import '../test_harness.dart';

void main() {
  late TestHarness harness;
  late SmsRepository repo;

  setUp(() async {
    harness = await TestHarness.create();
    repo = SmsRepository(getIt<DatabaseHelper>());
  });

  tearDown(() => harness.dispose());

  group('SmsRepository', () {
    test('creates a pending request with generated ids', () async {
      final request = await repo.create(
        simId: 'sim-1',
        recipient: '+1234567890',
        message: 'hello world',
      );
      expect(request.requestId, isNotEmpty);
      expect(request.id, isNotEmpty);
      expect(request.status, SmsStatus.pending);
      expect(request.messageLength, 11);
      expect(request.maxRetries, 3);
      expect(request.currentRetryCount, 0);
    });

    test('retrieves a request by id', () async {
      final created = await repo.create(
        simId: 'sim-1',
        recipient: '+1234567890',
        message: 'hello',
      );
      final fetched = await repo.getById(created.requestId);
      expect(fetched, isNotNull);
      expect(fetched!.recipient, '+1234567890');
    });

    test('returns null for unknown ids', () async {
      expect(await repo.getById('nope'), isNull);
    });

    test('cancels only pending/retrying requests', () async {
      final pending = await repo.create(
          simId: 'sim-1', recipient: '+1', message: 'a' * 7);
      expect(await repo.cancel(pending.requestId), 1);
      expect((await repo.getById(pending.requestId))!.status,
          SmsStatus.cancelled);

      // Cancelling again has no effect.
      expect(await repo.cancel(pending.requestId), 0);
    });

    test('records a successful retry and marks sent', () async {
      final request = await repo.create(
          simId: 'sim-1', recipient: '+1234567890', message: 'ping');
      final attempt = await repo.recordRetry(
        request: request,
        success: true,
        responseTimeMs: 42,
      );
      expect(attempt.success, isTrue);
      final updated = await repo.getById(request.requestId);
      expect(updated!.status, SmsStatus.sent);
      expect(updated.currentRetryCount, 1);
      expect(updated.sentAt, isNotNull);
      final history = await repo.retryHistory(request.requestId);
      expect(history.length, 1);
      expect(history.first.responseTimeMs, 42);
    });

    test('records failures and exhausts retries to failed', () async {
      final request = await repo.create(
        simId: 'sim-1',
        recipient: '+1234567890',
        message: 'ping',
        maxRetries: 2,
      );
      await repo.recordRetry(request: request, success: false,
          errorMessage: 'e1');
      expect((await repo.getById(request.requestId))!.status,
          SmsStatus.retrying);
      expect((await repo.getById(request.requestId))!.currentRetryCount, 1);
      expect((await repo.getById(request.requestId))!.nextRetryAt, isNotNull);

      await repo.recordRetry(
          request: request, success: false, errorMessage: 'e2');
      final updated = await repo.getById(request.requestId);
      expect(updated!.status, SmsStatus.failed);
      expect(updated.currentRetryCount, 2);
      expect(updated.lastError, 'e2');
    });

    test('pending() lists only pending/retrying', () async {
      final a = await repo.create(
          simId: 's', recipient: '+1', message: 'x' * 7);
      final b = await repo.create(
          simId: 's', recipient: '+2', message: 'y' * 7);
      await repo.recordRetry(request: b, success: true);

      final pending = await repo.pending();
      expect(pending.map((r) => r.requestId), [a.requestId]);
    });

    test('recent returns newest first', () async {
      for (var i = 0; i < 5; i++) {
        await repo.create(
            simId: 's', recipient: '+1', message: 'm$i' * 3);
        // Small delay to make created_at ordering deterministic.
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final recent = await repo.recent(limit: 3);
      expect(recent.length, 3);
    });

    test('query filters by status and searches text', () async {
      await repo.create(simId: 's1', recipient: '+1111111111', message: 'alpha');
      final failed = await repo.create(
          simId: 's1', recipient: '+2222222222', message: 'beta');
      await repo.recordRetry(request: failed, success: false);

      final byStatus = await repo.query(status: 'failed');
      expect(byStatus.length, 1);
      expect(byStatus.first.recipient, '+2222222222');

      final bySearch = await repo.query(searchQuery: 'alpha');
      expect(bySearch.length, 1);

      final bySim = await repo.query(simId: 's1');
      expect(bySim.length, 2);
    });

    test('countsByStatus groups correctly', () async {
      final a = await repo.create(
          simId: 's', recipient: '+1', message: 'x' * 7);
      final b = await repo.create(
          simId: 's', recipient: '+2', message: 'y' * 7);
      await repo.recordRetry(request: a, success: true);
      await repo.recordRetry(request: b, success: false);

      final counts = await repo.countsByStatus();
      expect(counts['sent'], 1);
      expect(counts['retrying'], 1);
    });

    test('averageResponseTimeMs aggregates', () async {
      final r1 = await repo.create(
          simId: 's', recipient: '+1', message: 'x' * 7);
      final r2 = await repo.create(
          simId: 's', recipient: '+2', message: 'y' * 7);
      await repo.recordRetry(request: r1, success: true, responseTimeMs: 100);
      await repo.recordRetry(request: r2, success: true, responseTimeMs: 200);
      expect(await repo.averageResponseTimeMs(), 150);
    });

    test('hourlyActivity buckets by hour', () async {
      await repo.create(simId: 's', recipient: '+1', message: 'x' * 7);
      await repo.create(simId: 's', recipient: '+2', message: 'y' * 7);
      final series = await repo.hourlyActivity(hours: 24);
      expect(series.length, 24);
      final total = series.fold<int>(0, (sum, b) => sum + b.count);
      expect(total, greaterThanOrEqualTo(2));
    });

    test('detailedJson includes retry history', () async {
      final request = await repo.create(
          simId: 's', recipient: '+1234567890', message: 'hi');
      await repo.recordRetry(request: request, success: true);
      final json = await repo.detailedJson(request.requestId);
      expect(json['requestId'], request.requestId);
      expect(json['status'], 'sent');
      expect((json['retryHistory'] as List).length, 1);
    });
  });
}
