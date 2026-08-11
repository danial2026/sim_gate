import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/config/theme.dart';
import 'package:sim_gate/pages/config_page.dart';
import 'package:sim_gate/providers/config_provider.dart';
import 'package:sim_gate/providers/server_provider.dart';
import 'package:sim_gate/repositories/logs_repository.dart';
import 'package:sim_gate/repositories/sim_repository.dart';
import 'package:sim_gate/repositories/sms_repository.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/retry_manager.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/sms_service.dart';
import 'package:sim_gate/services/token_service.dart';
import 'package:sim_gate/server/http_server.dart';

import 'test_harness.dart';

class _FakeHttpServer extends HttpServerService {
  _FakeHttpServer({required super.smsService, required super.simService, required super.smsRepo, required super.simRepo, required super.logsRepo, required super.tokenService, required super.configService});
  final _states = StreamController<ServerState>.broadcast();
  bool running = false;
  @override Stream<ServerState> get stateStream => _states.stream;
  @override bool get isRunning => running;
  @override DateTime? get startTime => DateTime.now().toUtc();
  @override Future<String> start({required String ip, required int port}) async {
    running = true;
    _states.add(ServerState.running);
    return 'http://$ip:$port';
  }
  @override Future<void> stop() async { running = false; _states.add(ServerState.stopped); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestHarness harness;
  setUp(() async { harness = await TestHarness.create(); });
  tearDown(() async { await harness.dispose(); });

  testWidgets('dbg', (tester) async {
    final fake = _FakeHttpServer(
      smsService: getIt<SmsService>(), simService: getIt<SimService>(),
      smsRepo: getIt<SmsRepository>(), simRepo: getIt<SimRepository>(),
      logsRepo: getIt<LogsRepository>(), tokenService: getIt<TokenService>(),
      configService: getIt<ConfigService>(),
    );
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
                httpServer: fake, retryManager: getIt<RetryManager>(),
              ),
            ),
          ],
          child: const ConfigPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    print('before: running=${fake.running}');
    await fake.start(ip: '0.0.0.0', port: 3000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    print('after: running=${fake.running}');
    final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
    print('TEXTS: $texts');
    final sp = Provider.of<ServerProvider>(tester.element(find.byType(ConfigPage)), listen: false);
    print('provider.isRunning=${sp.isRunning}');
  });
}
