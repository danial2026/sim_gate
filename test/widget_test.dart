// App-level smoke test: boots the whole widget tree with test wiring and
// verifies the first screen renders without exceptions.

import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/main.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';

import 'test_harness.dart';

/// Lets real-async work (FFI SQLite) complete under the FakeAsync test zone.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
    // Ensure a SIM exists so the dashboard has data to show.
    final platform = getIt<PlatformChannelService>() as FakePlatformService;
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

  testWidgets('onboarding flow ends on the server config page', (tester) async {
    await tester.pumpWidget(const SimGateApp());
    await settleDb(tester);

    // Permissions gate -> Setup (mock channel grants everything).
    await tester.tap(find.text('CONTINUE'));
    await settleDb(tester);
    expect(find.text('CONFIGURE SERVER'), findsOneWidget);

    // Setup -> SIM selection.
    await tester.tap(find.text('CONTINUE'));
    await settleDb(tester);
    expect(find.text('SIM CARDS'), findsOneWidget);
    expect(find.text('SIM 1'), findsOneWidget);

    // SIM selection -> Server configuration.
    await tester.tap(find.text('CONTINUE'));
    await settleDb(tester);
    expect(find.text('SERVER CONFIGURATION'), findsOneWidget);
    expect(find.text('START API'), findsOneWidget);
    expect(find.text('OPEN DASHBOARD'), findsNothing);
  });
}
