import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sim_gate/config/service_locator.dart';
import 'package:sim_gate/models/configuration.dart';
import 'package:sim_gate/repositories/config_repository.dart';
import 'package:sim_gate/services/token_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await resetGetIt();
  });

  group('ConfigRepository', () {
    test('applies defaults when nothing is stored', () {
      final repo = ConfigRepository(prefs!);
      final config = repo.load();
      expect(config.serverIp, '0.0.0.0');
      expect(config.serverPort, 3000);
      expect(config.accessToken, isNull);
      expect(config.autoStartServer, isFalse);
      expect(config.logLevel, 'info');
      expect(config.logRetentionDays, 30);
      expect(config.maxLogEntries, 10000);
      expect(config.appTheme, AppThemeMode.system);
      expect(config.activeSimIds, isEmpty);
      expect(config.enableSwagger, isFalse);
    });

    test('round-trips a full configuration', () async {
      final repo = ConfigRepository(prefs!);
      await repo.save(
        AppConfiguration(
          serverIp: '192.168.1.10',
          serverPort: 8080,
          accessToken: 'abc123',
          tokenGeneratedAt: DateTime.utc(2026, 1, 1),
          autoStartServer: true,
          logLevel: 'debug',
          logRetentionDays: 7,
          maxLogEntries: 500,
          appTheme: AppThemeMode.dark,
          activeSimIds: ['sim-1', 'sim-2'],
          enableSwagger: true,
        ),
      );
      final loaded = repo.load();
      expect(loaded.serverIp, '192.168.1.10');
      expect(loaded.serverPort, 8080);
      expect(loaded.accessToken, 'abc123');
      expect(loaded.tokenGeneratedAt, DateTime.utc(2026, 1, 1));
      expect(loaded.autoStartServer, isTrue);
      expect(loaded.logLevel, 'debug');
      expect(loaded.logRetentionDays, 7);
      expect(loaded.maxLogEntries, 500);
      expect(loaded.appTheme, AppThemeMode.dark);
      expect(loaded.activeSimIds, ['sim-1', 'sim-2']);
      expect(loaded.enableSwagger, isTrue);
    });

    test('saveToken persists token and timestamp', () async {
      final repo = ConfigRepository(prefs!);
      await repo.saveToken('token-123', DateTime.utc(2026, 2, 2));
      final loaded = repo.load();
      expect(loaded.accessToken, 'token-123');
      expect(loaded.tokenGeneratedAt, DateTime.utc(2026, 2, 2));
    });

    test('savePort and saveIp persist independently', () async {
      final repo = ConfigRepository(prefs!);
      await repo.savePort(9000);
      await repo.saveIp('127.0.0.1');
      final loaded = repo.load();
      expect(loaded.serverPort, 9000);
      expect(loaded.serverIp, '127.0.0.1');
    });
  });

  group('TokenService', () {
    test('generates a 64-char token on first use', () async {
      final repo = ConfigRepository(prefs!);
      final service = TokenService(config: repo);
      final token = await service.ensureToken();
      expect(token.length, 64);
      expect(token, isNot(contains(' ')));
    });

    test('never regenerates an existing token', () async {
      final repo = ConfigRepository(prefs!);
      final service = TokenService(config: repo);
      final first = await service.ensureToken();
      final second = await service.ensureToken();
      expect(second, first);
    });

    test('validate accepts only the stored token', () async {
      final repo = ConfigRepository(prefs!);
      final service = TokenService(config: repo);
      final token = await service.ensureToken();
      expect(service.validate(token), isTrue);
      expect(service.validate('wrong-token'), isFalse);
      expect(service.validate(null), isFalse);
      expect(service.validate(''), isFalse);
    });

    test('regenerate replaces the stored token', () async {
      final repo = ConfigRepository(prefs!);
      final service = TokenService(config: repo);
      final old = await service.ensureToken();
      final fresh = await service.regenerate();
      expect(fresh, isNot(old));
      expect(service.validate(old), isFalse);
      expect(service.validate(fresh), isTrue);
    });

    test('mask shows prefix/suffix only', () async {
      final service = TokenService(config: ConfigRepository(prefs!));
      expect(service.mask('abcdefgh12345678'), 'abcd...5678');
    });

    test('apiUrlWithToken includes the token', () async {
      final repo = ConfigRepository(prefs!);
      await repo.save(
        AppConfiguration(
          serverIp: '0.0.0.0',
          serverPort: 3000,
          accessToken: 'tok123',
        ),
      );
      final config = repo.load();
      expect(config.apiUrl, 'http://0.0.0.0:3000/api');
      expect(config.apiUrlWithToken, 'http://0.0.0.0:3000/api?token=tok123');
    });
  });
}
