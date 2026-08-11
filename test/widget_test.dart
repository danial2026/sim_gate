// App-level smoke test: boots the whole widget tree with test wiring and
// verifies the first screen renders without exceptions.

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
    // Ensure a SIM exists so the dashboard has data to show.
    final platform =
        getIt<PlatformChannelService>() as FakePlatformService;
    platform.setSims([
      SimCard(
        simId: 'sim-0',
        slotNumber: 0,
        name: 'SIM 1',
        phoneNumber: '+1234000001',
        carrier: 'TestNet',
        signalStrength: 4,
      ),
    ]);
    await getIt<SimService>().refresh();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('app boots and shows the permissions screen', (tester) async {
    await tester.pumpWidget(const SimGateApp());
    await tester.pumpAndSettle();

    // First screen is the permissions gate.
    expect(find.text('PERMISSIONS'), findsOneWidget);
    expect(find.text('Grant Permissions'), findsOneWidget);
  });
}
