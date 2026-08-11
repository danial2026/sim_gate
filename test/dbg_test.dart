import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/main.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
    final platform = getIt<PlatformChannelService>() as FakePlatformService;
    platform.setSims([
      SimCard(simId: 'sim-0', slotNumber: 0, name: 'SIM 1', phoneNumber: '+1234000001', carrier: 'TestNet', signalStrength: 4),
    ]);
    await getIt<SimService>().refresh();
    print('SETUP: refresh done');
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('debug app boot', (tester) async {
    await tester.pumpWidget(const SimGateApp());
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (!tester.binding.hasScheduledFrame) break;
      print('BODY pump $i scheduled=${tester.binding.hasScheduledFrame}');
    }
    print('FINAL scheduled=${tester.binding.hasScheduledFrame}');
    expect(find.text('Grant Permissions'), findsOneWidget);
  });
}
