import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/server/http_server.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/token_service.dart';
import 'package:shelf/shelf.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/server/swagger/swagger_spec.dart';
import 'package:sim_gate/server/handlers/swagger_handler.dart';
import 'package:sim_gate/config/app_info.dart';
import 'test_harness.dart';

@Timeout(Duration(minutes: 30))
void main() {
  test('probe swagger UI with a live server', () async {
    final harness = await TestHarness.create();
    final platform = getIt<PlatformChannelService>() as FakePlatformService;
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
      SimCard(
        simId: 'sim-1',
        slotNumber: 1,
        name: 'SIM 2',
        phoneNumber: '+1234000002',
        carrier: 'TestNet2',
        signalStrength: 2,
        isActive: false,
      ),
    ]);
    await getIt<SimService>().refresh();
    await getIt<TokenService>().ensureToken();
    await getIt<ConfigService>().updateSwaggerEnabled(true);
    final server = getIt<HttpServerService>();
    final baseUrl = await server.start(ip: '127.0.0.1', port: 0);
    // ignore: avoid_print
    print('PROBE_BASEURL:$baseUrl');
    try {
      final spec = SwaggerSpecBuilder(
        config: getIt<ConfigService>().load(),
        sims: await getIt<SimService>().getAll(),
        appVersion: '0.0.4',
        serverOrigin: 'http://127.0.0.1:1',
      ).build();
      // ignore: avoid_print
      print('SPEC_BUILD_OK paths=${spec['paths']?.length}');
      final json = encodeSpec(spec);
      // ignore: avoid_print
      print('ENCODE_OK len=${json.length}');
      final handler = SwaggerHandler(
        configService: getIt<ConfigService>(),
        simService: getIt<SimService>(),
        appVersion: '0.0.4',
      );
      final res = await handler.spec(Request(
        'GET',
        Uri.parse('http://127.0.0.1:1/swagger.json'),
      ));
      // ignore: avoid_print
      print('HANDLER_OK status=${res.statusCode}');
    } catch (e, st) {
      // ignore: avoid_print
      print('SPEC_BUILD_ERROR: $e\n$st');
    }
    await Future<void>.delayed(const Duration(days: 1));
  });
}