import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/models/sms_request.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/retry_manager.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/sms_service.dart';

import '../test_harness.dart';

void main() {
  late TestHarness harness;
  late SmsService smsService;
  late SimService simService;
  late FakePlatformService platform;

  setUp(() async {
    harness = await TestHarness.create();
    platform = getIt<PlatformChannelService>() as FakePlatformService;
    platform.setSims([
      SimCard(
        simId: 'sim-0',
        slotNumber: 0,
        name: 'SIM 1',
        phoneNumber: '+1234000001',
        carrier: 'TestNet',
        signalStrength: 4,
        isActive: true,
      ),
    ]);
    smsService = getIt<SmsService>();
    simService = getIt<SimService>();
    await simService.refresh();
  });

  tearDown(() => harness.dispose());

  group('SmsService', () {
    test('queue rejects invalid recipients', () async {
      expect(
        () => smsService.queue(
            simId: 'sim-0', recipient: 'abc', message: 'hello'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('queue rejects empty messages', () async {
      expect(
        () => smsService.queue(
            simId: 'sim-0', recipient: '+1234567890', message: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('queue rejects oversized messages', () async {
      expect(
        () => smsService.queue(
            simId: 'sim-0', recipient: '+1234567890', message: 'x' * 1601),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('queue rejects empty simId', () async {
      expect(
        () => smsService.queue(
            simId: '', recipient: '+1234567890', message: 'hi'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sendNow sends and marks the request sent', () async {
      final request = await smsService.sendNow(
        simId: 'sim-0',
        recipient: '+1234567890',
        message: 'Hello world',
      );
      expect(request.status, SmsStatus.sent);
      expect(request.sentAt, isNotNull);
      expect(platform.lastSendArgs!['recipient'], '+1234567890');
      expect(platform.lastSendArgs!['message'], 'Hello world');
    });

    test('sendNow keeps the request retrying on platform failure', () async {
      platform.setSendSucceeds(false);
      final request = await smsService.sendNow(
        simId: 'sim-0',
        recipient: '+1234567890',
        message: 'will fail',
        maxRetries: 3,
      );
      expect(request.status, SmsStatus.retrying);
      expect(request.lastError, isNotNull);
    });

    test('cancel flips pending to cancelled', () async {
      final request = await smsService.queue(
          simId: 'sim-0', recipient: '+1234567890', message: 'hi');
      final rows = await smsService.cancel(request.requestId);
      expect(rows, 1);
    });

    test('detailedStatus throws for unknown requests', () async {
      expect(smsService.detailedStatus('missing'),
          throwsA(isA<StateError>()));
    });
  });

  group('SimService', () {
    test('refresh persists detected sims', () async {
      final sims = await simService.getAll();
      expect(sims.length, 1);
      expect(sims.first.simId, 'sim-0');
    });

    test('toggle enforces at least one active sim', () async {
      expect(() => simService.toggle('sim-0', false),
          throwsA(isA<StateError>()));
      // With requireOne disabled it succeeds.
      final toggled = await simService.toggle('sim-0', false, requireOne: false);
      expect(toggled, isFalse);
      expect(await simService.activeCount(), 0);
    });

    test('toggle activates/deactivates freely when multiple exist', () async {
      platform.setSims([
        SimCard(
            simId: 'sim-0',
            slotNumber: 0,
            name: 'SIM 1',
            isActive: true),
        SimCard(
            simId: 'sim-1',
            slotNumber: 1,
            name: 'SIM 2',
            isActive: true),
      ]);
      await simService.refresh();
      await simService.toggle('sim-0', false);
      final active = await simService.getActive();
      expect(active.map((s) => s.simId), ['sim-1']);
      expect(await simService.totalCount(), 2);
    });
  });

  group('RetryManager', () {
    test('tick drains pending requests', () async {
      platform.setSendSucceeds(true);
      final queued = await smsService.queue(
        simId: 'sim-0',
        recipient: '+1234567890',
        message: 'queued',
      );
      expect(queued.status, SmsStatus.pending);

      final manager = getIt<RetryManager>();
      final processed = await manager.tick();
      expect(processed, 1);

      final updated = await smsService.detailedStatus(queued.requestId);
      expect(updated['status'], 'sent');
    });

    test('tick respects retry backoff windows', () async {
      platform.setSendSucceeds(false);
      final queued = await smsService.queue(
        simId: 'sim-0',
        recipient: '+1234567890',
        message: 'backoff me',
        maxRetries: 3,
      );
      final manager = getIt<RetryManager>();
      await manager.tick(); // first attempt -> retrying with backoff
      final processed = await manager.tick(); // backoff not elapsed
      expect(processed, 0);
    });
  });
}
