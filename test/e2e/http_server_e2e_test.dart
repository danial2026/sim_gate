import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/models/sim_card.dart';
import 'package:sim_gate/server/http_server.dart';
import 'package:sim_gate/services/config_service.dart';
import 'package:sim_gate/services/platform_channel_service.dart';
import 'package:sim_gate/services/sim_service.dart';
import 'package:sim_gate/services/token_service.dart';

import '../test_harness.dart';

/// End-to-end tests: boot the real shelf server on a random port and drive
/// it with dart:io HTTP clients exactly like an external app would.
void main() {
  late TestHarness harness;
  late HttpServerService server;
  late String baseUrl;
  late String token;
  late FakePlatformService platform;

  Future<HttpClientResponse> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? authToken,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = await client.openUrl(method, uri);
      if (authToken != null) {
        req.headers.set('Authorization', 'Bearer $authToken');
      }
      req.headers.set('Content-Type', 'application/json');
      if (body != null) {
        req.write(jsonEncode(body));
      }
      return await req.close();
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> readJson(HttpClientResponse res) async {
    final raw = await res.transform(utf8.decoder).join();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  setUp(() async {
    harness = await TestHarness.create();
    platform = getIt<PlatformChannelService>() as FakePlatformService;
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

    server = getIt<HttpServerService>();
    baseUrl = await server.start(ip: '127.0.0.1', port: 0);
    token = await getIt<TokenService>().ensureToken();
  });

  tearDown(() async {
    await server.dispose();
    await harness.dispose();
  });

  group('Health', () {
    test('GET /api/health works without auth', () async {
      final res = await request('GET', '/api/health');
      expect(res.statusCode, 200);
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['status'], 'running');
      expect(json['data']['version'], '0.0.1');
    });
  });

  group('Authentication', () {
    test('protected endpoints reject missing token', () async {
      final res = await request('GET', '/api/server/info');
      expect(res.statusCode, 401);
      final json = await readJson(res);
      expect(json['success'], isFalse);
      expect(json['error'], contains('Unauthorized'));
    });

    test('protected endpoints reject wrong token', () async {
      final res = await request('GET', '/api/server/info', authToken: 'wrong');
      expect(res.statusCode, 401);
    });

    test('protected endpoints accept the stored token', () async {
      final res = await request('GET', '/api/server/info', authToken: token);
      expect(res.statusCode, 200);
    });
  });

  group('POST /api/sms/send', () {
    test('sends successfully with a valid body', () async {
      final res = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': '+1234567890',
          'message': 'Hello via HTTP',
        },
      );
      expect(res.statusCode, 200);
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['status'], 'sent');
      expect(json['data']['requestId'], isNotEmpty);
      expect(json['data']['recipient'], '+1234567890');
    });

    test('returns 400 for a missing recipient', () async {
      final res = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {'simId': 'sim-0', 'message': 'no recipient'},
      );
      expect(res.statusCode, 400);
      final json = await readJson(res);
      expect(json['success'], isFalse);
    });

    test('returns 400 for an invalid recipient format', () async {
      final res = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': 'not-a-number',
          'message': 'hello',
        },
      );
      expect(res.statusCode, 400);
    });

    test('returns 400 for an empty message', () async {
      final res = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {'simId': 'sim-0', 'recipient': '+1234567890', 'message': ''},
      );
      expect(res.statusCode, 400);
    });

    test('returns 400 for invalid JSON', () async {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('$baseUrl/api/sms/send'));
      req.headers.set('Authorization', 'Bearer $token');
      req.write('{not json');
      final res = await req.close();
      client.close(force: true);
      expect(res.statusCode, 400);
    });
  });

  group('GET /api/sms/status', () {
    test('returns the full lifecycle for a sent request', () async {
      final send = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': '+1234567890',
          'message': 'track me',
        },
      );
      final sendJson = await readJson(send);
      final requestId = sendJson['data']['requestId'];

      final res = await request(
        'GET',
        '/api/sms/status?requestId=$requestId',
        authToken: token,
      );
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['status'], 'sent');
      expect(json['data']['retryCount'], 1);
    });

    test('returns 404 for unknown requests', () async {
      final res = await request(
        'GET',
        '/api/sms/status?requestId=missing',
        authToken: token,
      );
      expect(res.statusCode, 404);
    });

    test('detailed=true includes retry history', () async {
      final send = await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': '+1234567890',
          'message': 'with history',
        },
      );
      final sendJson = await readJson(send);
      final requestId = sendJson['data']['requestId'];
      final res = await request(
        'GET',
        '/api/sms/status?requestId=$requestId&detailed=true',
        authToken: token,
      );
      final json = await readJson(res);
      final history = json['data']['retryHistory'] as List;
      expect(history, isNotEmpty);
      expect(history.first['attempt'], 1);
    });
  });

  group('GET /api/sms/logs', () {
    test('lists sent requests with pagination metadata', () async {
      await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': '+1234567890',
          'message': 'log me',
        },
      );
      final res = await request('GET', '/api/sms/logs', authToken: token);
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['total'], greaterThanOrEqualTo(1));
      expect(json['data']['limit'], 20);
      expect(json['data']['offset'], 0);
    });

    test('filters by status and search', () async {
      await request(
        'POST',
        '/api/sms/send',
        authToken: token,
        body: {
          'simId': 'sim-0',
          'recipient': '+1111111111',
          'message': 'needle message',
        },
      );
      final res = await request(
        'GET',
        '/api/sms/logs?status=sent&searchQuery=needle',
        authToken: token,
      );
      final json = await readJson(res);
      expect(json['data']['total'], 1);
    });
  });

  group('GET /api/sims/active', () {
    test('returns sim cards with active counts', () async {
      final res = await request('GET', '/api/sims/active', authToken: token);
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['totalSIMCount'], 2);
      expect(json['data']['activeSIMCount'], 1);
      final cards = json['data']['simCards'] as List;
      expect(cards.first['simId'], 'sim-0');
      expect(cards.first['signalStrength'], 4);
    });
  });

  group('POST /api/sims/activate', () {
    test('activates a sim card', () async {
      final res = await request(
        'POST',
        '/api/sims/activate',
        authToken: token,
        body: {'simId': 'sim-1', 'activate': true},
      );
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['isActive'], isTrue);

      final active = await request('GET', '/api/sims/active', authToken: token);
      final activeJson = await readJson(active);
      expect(activeJson['data']['activeSIMCount'], 2);
    });

    test('rejects deactivating the last active sim', () async {
      final res = await request(
        'POST',
        '/api/sims/activate',
        authToken: token,
        body: {'simId': 'sim-0', 'activate': false},
      );
      expect(res.statusCode, 409);
    });
  });

  group('GET /api/server/info', () {
    test('reports server details', () async {
      final res = await request('GET', '/api/server/info', authToken: token);
      final json = await readJson(res);
      expect(json['success'], isTrue);
      final data = json['data'];
      expect(data['serverStatus'], 'running');
      expect(data['version'], '0.0.1');
      expect(data['listeningPort'], isA<int>());
      expect(data['activeSims'], 1);
      expect(data['totalSims'], 2);
    });
  });

  group('PUT /api/config/port', () {
    test('validates the port range', () async {
      final res = await request(
        'PUT',
        '/api/config/port',
        authToken: token,
        body: {'port': 80},
      );
      expect(res.statusCode, 400);

      final ok = await request(
        'PUT',
        '/api/config/port',
        authToken: token,
        body: {'port': 8080},
      );
      final json = await readJson(ok);
      expect(json['success'], isTrue);
      expect(json['data']['newPort'], 8080);
    });
  });

  group('PUT /api/config/ip', () {
    test('validates the ip format', () async {
      final bad = await request(
        'PUT',
        '/api/config/ip',
        authToken: token,
        body: {'ip': '999.1.1.1'},
      );
      expect(bad.statusCode, 400);

      final ok = await request(
        'PUT',
        '/api/config/ip',
        authToken: token,
        body: {'ip': '192.168.1.10'},
      );
      final json = await readJson(ok);
      expect(json['success'], isTrue);
      expect(json['data']['newIP'], '192.168.1.10');
    });
  });

  group('POST /api/token/regenerate', () {
    test('invalidates the old token', () async {
      final res = await request(
        'POST',
        '/api/token/regenerate',
        authToken: token,
        body: {},
      );
      final json = await readJson(res);
      expect(json['success'], isTrue);
      expect(json['data']['newToken'], isNotEmpty);

      final oldToken = await request(
        'GET',
        '/api/server/info',
        authToken: token,
      );
      expect(oldToken.statusCode, 401);
      final newToken = await request(
        'GET',
        '/api/server/info',
        authToken: json['data']['newToken'],
      );
      expect(newToken.statusCode, 200);
    });
  });

  group('CORS', () {
    test('responds to preflight OPTIONS', () async {
      final client = HttpClient();
      final req = await client.openUrl(
        'OPTIONS',
        Uri.parse('$baseUrl/api/sms/send'),
      );
      final res = await req.close();
      client.close(force: true);
      expect(res.statusCode, 204);
      expect(res.headers.value('Access-Control-Allow-Origin'), '*');
    });
  });

  group('Swagger docs', () {
    test('returns 404 for docs when disabled', () async {
      await getIt<ConfigService>().updateSwaggerEnabled(false);
      final res = await request('GET', '/swagger.html');
      expect(res.statusCode, 404);
      final json = await readJson(res);
      expect(json['success'], isFalse);
    });

    test('serves the html page when enabled', () async {
      await getIt<ConfigService>().updateSwaggerEnabled(true);
      final res = await request('GET', '/swagger.html');
      expect(res.statusCode, 200);
      expect(res.headers.value('content-type'), contains('text/html'));
      final raw = await res.transform(utf8.decoder).join();
      expect(raw, contains('SimGate API Docs'));
      expect(raw, contains('swagger.json'));
    });

    test('serves an OpenAPI spec with live config values when enabled', () async {
      await getIt<ConfigService>().updateSwaggerEnabled(true);
      final res = await request('GET', '/swagger.json');
      expect(res.statusCode, 200);
      final spec = await readJson(res);
      expect(spec['openapi'], '3.0.3');
      expect(spec['info']['title'], contains('SimGate'));
      expect(spec['x-access-token'], token);
      expect(spec['paths'], contains('/api/sms/send'));
      expect(spec['paths'], contains('/api/sims/active'));

      // Live config values are embedded as examples.
      final send = spec['paths']['/api/sms/send']['post'];
      final sendExample =
          send['requestBody']['content']['application/json']['example'];
      expect(sendExample['simId'], 'sim-0');
      expect(sendExample['recipient'], '+1234000001');

      final portExample =
          spec['paths']['/api/config/port']['put']['requestBody']['content']['application/json']['example'];
      expect(portExample['port'], getIt<ConfigService>().load().serverPort);

      // Bearer auth is declared.
      expect(spec['security'], isNotEmpty);
      expect(
        spec['components']['securitySchemes']['bearerAuth']['scheme'],
        'bearer',
      );
    });

    test('spec examples reflect sim list changes', () async {
      await getIt<ConfigService>().updateSwaggerEnabled(true);
      final res = await request('GET', '/swagger.json');
      final spec = await readJson(res);
      final cards =
          spec['paths']['/api/sims/active']['get']['responses']['200']['content']['application/json']['example']['data']['simCards'];
      expect(cards.length, 2);
      expect(cards.first['simId'], 'sim-0');
    });
  });
}
