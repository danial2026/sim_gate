import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/pages/sim_cards_page.dart';
import 'package:sim_gate/providers/sim_provider.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';

import 'test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('debug sims page', (tester) async {
    final platform = getIt<PlatformChannelService>() as FakePlatformService;
    platform.setSims([
      SimCard(simId: 'sim-0', slotNumber: 0, name: 'SIM 1', phoneNumber: '+1', carrier: 'T', signalStrength: 4),
      SimCard(simId: 'sim-1', slotNumber: 1, name: 'SIM 2', phoneNumber: '+2', carrier: 'T2', signalStrength: 2),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ChangeNotifierProvider<SimProvider>(
          create: (_) => SimProvider(simService: getIt<SimService>()),
          child: const SimCardsPage(),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final p = Provider.of<SimProvider>(tester.element(find.byType(SimCardsPage)), listen: false);
      debugPrint('pump $i: scheduled=${tester.binding.hasScheduledFrame} sims=${p.sims.length} loading=${p.isLoading}');
    }
    expect(find.text('SIM 1'), findsOneWidget);
  });
}
