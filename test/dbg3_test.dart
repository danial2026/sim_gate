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
  });
  tearDown(() async { await harness.dispose(); });

  testWidgets('dbg', (tester) async {
    await tester.pumpWidget(const SimGateApp());
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
    final buttons = find.byType(TextButton).evaluate().map((e) => ((e.widget as TextButton).child as Text?)?.data).toList();
    print('TEXTS: $texts');
    print('btn: ${find.text('Continue').evaluate().length} / ${find.text('Grant All').evaluate().length}');
  });
}
