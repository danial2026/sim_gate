import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_helper.dart';
import '../repositories/config_repository.dart';
import '../repositories/logs_repository.dart';
import '../repositories/sim_repository.dart';
import '../repositories/sms_repository.dart';
import '../services/config_service.dart';
import '../services/background_service.dart';
import '../services/logger_service.dart';
import '../services/platform_channel_service.dart';
import '../services/retry_manager.dart';
import '../services/sim_service.dart';
import '../services/sms_service.dart';
import '../services/token_service.dart';
import '../server/http_server.dart';
import '../utils/logger.dart';
import 'app_info.dart';

/// Central dependency injection container.
///
/// Call [setup] once during `main()` before `runApp`. Tests can call
/// [setupForTest] to wire up FFI-backed database + fake platform service.
final GetIt getIt = GetIt.instance;

/// Wires up all services for the production app (Android).
Future<void> setup() async {
  // Logger first so other services can use it.
  final loggerService = LoggerService();
  getIt.registerSingleton<LoggerService>(loggerService);
  getIt.registerSingleton<Logger>(loggerService.logger);

  // App metadata from package_info_plus (single source: pubspec.yaml).
  getIt.registerSingleton<AppInfo>(await AppInfo.load());

  // Database (platform default on Android).
  final dbHelper = DatabaseHelper();
  getIt.registerSingleton<DatabaseHelper>(dbHelper);

  // Repositories.
  final prefs = await SharedPreferences.getInstance();
  final configRepo = ConfigRepository(prefs);
  final smsRepo = SmsRepository(dbHelper);
  final simRepo = SimRepository(dbHelper);
  final logsRepo = LogsRepository(dbHelper);
  getIt.registerSingleton<ConfigRepository>(configRepo);
  getIt.registerSingleton<SmsRepository>(smsRepo);
  getIt.registerSingleton<SimRepository>(simRepo);
  getIt.registerSingleton<LogsRepository>(logsRepo);

  // Attach database log sink now that the logs repo is ready.
  loggerService.attachDatabaseSink(logsRepo);

  // Services.
  final platform = MethodChannelPlatformService(logger: getIt<Logger>());
  final tokenService = TokenService(
    config: configRepo,
    logger: getIt<Logger>(),
  );
  final configService = ConfigService(
    repository: configRepo,
    logger: getIt<Logger>(),
  );
  final smsService = SmsService(
    repository: smsRepo,
    platform: platform,
    logger: getIt<Logger>(),
  );
  final simService = SimService(
    repository: simRepo,
    platform: platform,
    logger: getIt<Logger>(),
  );
  final retryManager = RetryManager(
    smsService: smsService,
    repository: smsRepo,
    logger: getIt<Logger>(),
  );
  final backgroundService = BackgroundService(
    platform: platform,
    logger: getIt<Logger>(),
  );

  getIt.registerSingleton<PlatformChannelService>(platform);
  getIt.registerSingleton<TokenService>(tokenService);
  getIt.registerSingleton<ConfigService>(configService);
  getIt.registerSingleton<SmsService>(smsService);
  getIt.registerSingleton<SimService>(simService);
  getIt.registerSingleton<RetryManager>(retryManager);
  getIt.registerSingleton<BackgroundService>(backgroundService);

  // HTTP server.
  final appInfo = getIt<AppInfo>();
  final httpServer = HttpServerService(
    smsService: smsService,
    simService: simService,
    smsRepo: smsRepo,
    simRepo: simRepo,
    logsRepo: logsRepo,
    tokenService: tokenService,
    configService: configService,
    appVersion: appInfo.version,
    logger: getIt<Logger>(),
  );
  getIt.registerSingleton<HttpServerService>(httpServer);
}

/// Wires up services for unit/integration tests with an in-memory FFI
/// database and a [FakePlatformService].
Future<void> setupForTest({
  required SharedPreferences prefs,
  String? dbPath,
  FakePlatformService? platform,
}) async {
  // Force FFI backend so tests run on the host machine. NoIsolate keeps
  // SQLite in-process so futures complete under the widget-test FakeAsync zone.
  sqfliteFfiInit();
  DatabaseHelper.overrideFactory = databaseFactoryFfiNoIsolate;

  // Stub app metadata: package_info_plus is unavailable on the host, so tests
  // register a fixed version that mirrors the current pubspec version.
  getIt.registerSingleton<AppInfo>(
    AppInfo(version: testAppVersion, buildNumber: 3),
    signalsReady: false,
  );

  final logger = Logger(minLevel: LogLevel.debug, sinks: const []);
  getIt.registerSingleton<Logger>(logger, signalsReady: false);

  final dbHelper = DatabaseHelper(pathOverride: dbPath);
  getIt.registerSingleton<DatabaseHelper>(dbHelper, signalsReady: false);

  final configRepo = ConfigRepository(prefs);
  final smsRepo = SmsRepository(dbHelper);
  final simRepo = SimRepository(dbHelper);
  final logsRepo = LogsRepository(dbHelper);
  getIt.registerSingleton<ConfigRepository>(configRepo);
  getIt.registerSingleton<SmsRepository>(smsRepo);
  getIt.registerSingleton<SimRepository>(simRepo);
  getIt.registerSingleton<LogsRepository>(logsRepo);

  final fakePlatform = platform ?? FakePlatformService();
  getIt.registerSingleton<PlatformChannelService>(fakePlatform);

  final tokenService = TokenService(config: configRepo, logger: logger);
  final configService = ConfigService(repository: configRepo, logger: logger);
  final smsService = SmsService(
    repository: smsRepo,
    platform: fakePlatform,
    logger: logger,
  );
  final simService = SimService(
    repository: simRepo,
    platform: fakePlatform,
    logger: logger,
  );
  final retryManager = RetryManager(
    smsService: smsService,
    repository: smsRepo,
    logger: logger,
  );
  final backgroundService = BackgroundService(
    platform: fakePlatform,
    logger: logger,
  );
  getIt.registerSingleton<TokenService>(tokenService);
  getIt.registerSingleton<ConfigService>(configService);
  getIt.registerSingleton<SmsService>(smsService);
  getIt.registerSingleton<SimService>(simService);
  getIt.registerSingleton<RetryManager>(retryManager);
  getIt.registerSingleton<BackgroundService>(backgroundService);

  final httpServer = HttpServerService(
    smsService: smsService,
    simService: simService,
    smsRepo: smsRepo,
    simRepo: simRepo,
    logsRepo: logsRepo,
    tokenService: tokenService,
    configService: configService,
    appVersion: getIt<AppInfo>().version,
    logger: logger,
  );
  getIt.registerSingleton<HttpServerService>(httpServer);
}

/// App version reported by the test harness. Mirrors the current version in
/// `pubspec.yaml` so host tests can assert against a stable value.
const String testAppVersion = '0.0.8';

/// Resets the DI container between tests.
Future<void> resetGetIt() async {
  await getIt.reset();
}
