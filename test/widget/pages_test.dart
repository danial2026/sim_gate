import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/pages/api_endpoint_page.dart';
import 'package:sim_gate/pages/config_page.dart';
import 'package:sim_gate/pages/dashboard_page.dart';
import 'package:sim_gate/pages/permissions_page.dart';
import 'package:sim_gate/pages/sim_cards_page.dart';
import 'package:sim_gate/providers/config_provider.dart';
import 'package:sim_gate/providers/server_provider.dart';
import 'package:sim_gate/providers/sim_provider.dart';
import 'package:sim_gate/providers/sms_provider.dart';
import 'package:sim_gate/repositories/logs_repository.dart';
import 'package:sim_gate/repositories/sim_repository.dart';
import 'package:sim_gate/repositories/sms_repository.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/retry_manager.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/sms_service.dart';
import 'package:sim_gate/services/token_service.dart';
import 'package:sim_gate/server/http_server.dart';
import 'package:sim_gate/widgets/dashboard/charts.dart';

import '../test_harness.dart';

/// Lets real-async work (FFI SQLite) complete under the FakeAsync test zone,
/// then settles the UI. Use after actions that trigger database calls.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// HttpServerService that never binds sockets; flips state via its stream.
class _FakeHttpServer extends HttpServerService {
  _FakeHttpServer({
    required super.smsService,
    required super.simService,
    required super.smsRepo,
    required super.simRepo,
    required super.logsRepo,
    required super.tokenService,
    required super.configService,
  });

  final _states = StreamController<ServerState>.broadcast();
  bool running = false;

  @override
  Stream<ServerState> get stateStream => _states.stream;

  @override
  bool get isRunning => running;

  @override
  DateTime? get startTime => DateTime.now().toUtc();

  @override
  Future<String> start({required String ip, required int port}) async {
    running = true;
    _states.add(ServerState.running);
    return 'http://$ip:$port';
  }

  @override
  Future<void> stop() async {
    running = false;
    _states.add(ServerState.stopped);
  }

  void disposeFake() => _states.close();
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
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.textContaining('http://'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('COPY URL'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('COPY URL'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('COPY AS CURL'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('COPY AS CURL'), findsOneWidget);
    });
  });

  group('PermissionsPage', () {
    testWidgets('back button asks for confirmation before closing the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const PermissionsPage()),
      );
      await settleDb(tester);
      expect(find.text('PERMISSIONS'), findsOneWidget);

      // Simulate the Android back button on the root page.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('CLOSE APP'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('EXIT'), findsOneWidget);

      // Cancelling keeps the page open.
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('CLOSE APP'), findsNothing);
      expect(find.text('PERMISSIONS'), findsOneWidget);

      // Back again + EXIT resolves the dialog and exits the app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('EXIT'));
      await tester.pumpAndSettle();
      expect(find.text('CLOSE APP'), findsNothing);
    });
  });

  group('DashboardPage', () {
    testWidgets('renders stats, charts and recent logs', (tester) async {
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

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConfigProvider>(
                create: (_) => ConfigProvider(
                  configService: getIt<ConfigService>(),
                  tokenService: getIt<TokenService>(),
                )..load(),
              ),
              ChangeNotifierProvider<SimProvider>(
                create: (_) => SimProvider(simService: getIt<SimService>()),
              ),
              ChangeNotifierProvider<SmsProvider>(
                create: (_) => SmsProvider(
                  smsService: getIt<SmsService>(),
                  smsRepository: getIt<SmsRepository>(),
                  simRepository: getIt<SimRepository>(),
                ),
              ),
              ChangeNotifierProvider<ServerProvider>(
                create: (_) => ServerProvider(
                  httpServer: getIt<HttpServerService>(),
                  retryManager: getIt<RetryManager>(),
                ),
              ),
            ],
            child: const DashboardPage(),
          ),
        ),
      );
      await settleDb(tester);

      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('QUICK ACCESS'), findsOneWidget);
      expect(find.text('STATISTICS'), findsOneWidget);

      // The chart section is below the fold; scroll it into view.
      await tester.scrollUntilVisible(
        find.byType(SuccessRateChart),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(SmsActivityChart), findsOneWidget);
      expect(find.byType(SuccessRateChart), findsOneWidget);
    });

    testWidgets('back button returns to the previous page', (tester) async {
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

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConfigProvider>(
              create: (_) => ConfigProvider(
                configService: getIt<ConfigService>(),
                tokenService: getIt<TokenService>(),
              )..load(),
            ),
            ChangeNotifierProvider<SimProvider>(
              create: (_) => SimProvider(simService: getIt<SimService>()),
            ),
            ChangeNotifierProvider<SmsProvider>(
              create: (_) => SmsProvider(
                smsService: getIt<SmsService>(),
                smsRepository: getIt<SmsRepository>(),
                simRepository: getIt<SimRepository>(),
              ),
            ),
            ChangeNotifierProvider<ServerProvider>(
              create: (_) => ServerProvider(
                httpServer: getIt<HttpServerService>(),
                retryManager: getIt<RetryManager>(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            routes: {
              '/config': (_) => const ConfigPage(),
              '/dashboard': (_) => const DashboardPage(),
            },
            home: const ConfigPage(),
          ),
        ),
      );
      await settleDb(tester);
      expect(find.text('SERVER CONFIGURATION'), findsOneWidget);

      // Push the dashboard on top (as the flow does after starting the API).
      Navigator.of(
        tester.element(find.text('SERVER CONFIGURATION')),
      ).pushNamed('/dashboard');
      await settleDb(tester);
      expect(find.text('DASHBOARD'), findsOneWidget);

      // The back button must return to the previous page...
      await tester.binding.handlePopRoute();
      await settleDb(tester);
      expect(find.text('DASHBOARD'), findsNothing);
      expect(find.text('SERVER CONFIGURATION'), findsOneWidget);
      // ...without any exit-confirmation dialog.
      expect(find.text('CLOSE APP'), findsNothing);
    });
  });

  group('ConfigPage', () {
    testWidgets('shows Open Dashboard only while the server is running', (
      tester,
    ) async {
      final fake = _FakeHttpServer(
        smsService: getIt<SmsService>(),
        simService: getIt<SimService>(),
        smsRepo: getIt<SmsRepository>(),
        simRepo: getIt<SimRepository>(),
        logsRepo: getIt<LogsRepository>(),
        tokenService: getIt<TokenService>(),
        configService: getIt<ConfigService>(),
      );
      addTearDown(fake.disposeFake);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<ConfigProvider>(
                create: (_) => ConfigProvider(
                  configService: getIt<ConfigService>(),
                  tokenService: getIt<TokenService>(),
                )..load(),
              ),
              ChangeNotifierProvider<ServerProvider>(
                create: (_) => ServerProvider(
                  httpServer: fake,
                  retryManager: getIt<RetryManager>(),
                ),
              ),
            ],
            child: const ConfigPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('START API'), findsOneWidget);
      expect(find.text('OPEN DASHBOARD'), findsNothing);

      await fake.start(ip: '0.0.0.0', port: 3000);
      await tester.pumpAndSettle();

      expect(find.text('STOP API'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('OPEN DASHBOARD'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('OPEN DASHBOARD'), findsOneWidget);
    });
  });

  group('SimCardsPage', () {
    testWidgets('shows no-sims state when nothing detected', (tester) async {
      final platform = getIt<PlatformChannelService>() as FakePlatformService;
      platform.setSims([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ChangeNotifierProvider<SimProvider>(
            create: (_) => SimProvider(simService: getIt<SimService>()),
            child: const SimCardsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No SIM Cards Available'), findsOneWidget);
    });

    testWidgets('lists detected SIM cards with toggles', (tester) async {
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
            create: (_) => SimProvider(simService: getIt<SimService>()),
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

      // Deactivating the last remaining active SIM (sim-1) is rejected.
      await tester.tap(find.byType(Switch).at(1));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('At least one SIM must remain active'), findsOneWidget);
    });

    testWidgets('Continue opens Server Configuration, not the dashboard', (
      tester,
    ) async {
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

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConfigProvider>(
              create: (_) => ConfigProvider(
                configService: getIt<ConfigService>(),
                tokenService: getIt<TokenService>(),
              )..load(),
            ),
            ChangeNotifierProvider<SimProvider>(
              create: (_) => SimProvider(simService: getIt<SimService>()),
            ),
            ChangeNotifierProvider<ServerProvider>(
              create: (_) => ServerProvider(
                httpServer: getIt<HttpServerService>(),
                retryManager: getIt<RetryManager>(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            routes: {
              '/config': (_) => const ConfigPage(),
              '/dashboard': (_) => const DashboardPage(),
            },
            home: const SimCardsPage(inFlow: true),
          ),
        ),
      );
      await settleDb(tester);

      await tester.scrollUntilVisible(
        find.text('CONTINUE'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('CONTINUE'));
      await settleDb(tester);

      // The next screen must be the Server Configuration page...
      expect(find.text('SERVER CONFIGURATION'), findsOneWidget);
      expect(find.text('START API'), findsOneWidget);
      // ...and never the dashboard.
      expect(find.byType(DashboardPage), findsNothing);
      expect(find.text('DASHBOARD'), findsNothing);
    });
  });
}
