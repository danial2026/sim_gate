import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/pages/settings_page.dart';
import 'package:sim_gate/providers/config_provider.dart';
import 'package:sim_gate/providers/logs_provider.dart';
import 'package:sim_gate/repositories/logs_repository.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/token_service.dart';

import '../test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;

  setUp(() async {
    harness = await TestHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('debug no-scroll stability', (tester) async {
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
            ChangeNotifierProvider<LogsProvider>(
              create: (_) =>
                  LogsProvider(logsRepository: getIt<LogsRepository>()),
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    final pos = tester.state<ScrollableState>(scrollable).position;

    String anchor() {
      final b = find.text('CLEAR').evaluate().isNotEmpty;
      final ip = find.text('IP Address').evaluate().isNotEmpty;
      final sw = find.text('API Docs (Swagger)').evaluate().isNotEmpty;
      final ex = find.text('EXPORT LOGS').evaluate().isNotEmpty;
      String rect(Finder f) => tester.getRect(f.first).top.toStringAsFixed(1);
      return 'off=${pos.pixels.toStringAsFixed(1)} max=${pos.maxScrollExtent.toStringAsFixed(1)} '
          'CLEAR=$b${b ? '@${rect(find.text('CLEAR'))}' : ''} IP=$ip${ip ? '@${rect(find.text('IP Address'))}' : ''} '
          'SW=$sw${sw ? '@${rect(find.text('API Docs (Swagger)'))}' : ''} EXPORT=$ex${ex ? '@${rect(find.text('EXPORT LOGS'))}' : ''}';
    }

    for (var i = 0; i < 10; i++) {
      debugPrint('pump $i: ${anchor()}');
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    debugPrint('settled: ${anchor()}');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      debugPrint('post-settle pump $i: ${anchor()}');
    }
  });
}
