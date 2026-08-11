import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/pages/api_endpoint_page.dart';
import 'package:sim_gate/pages/sim_cards_page.dart';
import 'package:sim_gate/providers/config_provider.dart';
import 'package:sim_gate/providers/sim_provider.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/token_service.dart';

import '../test_harness.dart';

/// Lets real-async work (FFI SQLite) complete under the FakeAsync test zone,
/// then settles the UI. Use after actions that trigger database calls.
Future<void> settleDb(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('ApiEndpointPage', () {
    testWidgets('renders QR code, URL, and copy actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<ConfigProvider>(
            create: (_) => ConfigProvider(
              configService: getIt<ConfigService>(),
              tokenService: getIt<TokenService>(),
            )..load(),
            child: const ApiEndpointPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('API ENDPOINT'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('COPY URL'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('COPY URL'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('COPY AS CURL'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('COPY AS CURL'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('http://'), findsWidgets);
    });
  });

  group('SimCardsPage', () {
    testWidgets('shows no-sims state when nothing detected', (tester) async {
      final platform =
          getIt<PlatformChannelService>() as FakePlatformService;
      platform.setSims([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<SimProvider>(
            create: (_) =>
                SimProvider(simService: getIt<SimService>()),
            child: const SimCardsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No SIM Cards Available'), findsOneWidget);
    });

    testWidgets('lists detected SIM cards with toggles', (tester) async {
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
        SimCard(
          simId: 'sim-1',
          slotNumber: 1,
          name: 'SIM 2',
          phoneNumber: '+1234000002',
          carrier: 'TestNet2',
          signalStrength: 2,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<SimProvider>(
            create: (_) =>
                SimProvider(simService: getIt<SimService>()),
            child: const SimCardsPage(),
          ),
        ),
      );
      await settleDb(tester);

      expect(find.text('SIM 1'), findsOneWidget);
      expect(find.text('SIM 2'), findsOneWidget);
      expect(find.text('+1234000001'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));

      // Deactivating one of two active SIMs is allowed.
      await tester.tap(find.byType(Switch).first);
      await settleDb(tester);

      // Deactivating the last remaining active SIM is rejected with a toast.
      await tester.tap(find.byType(Switch).first);
      await settleDb(tester);
      expect(find.text('At least one SIM must remain active'), findsOneWidget);
    });
  });
}
