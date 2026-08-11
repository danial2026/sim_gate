import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../database/database_helper.dart';
import '../repositories/config_repository.dart';
import '../repositories/logs_repository.dart';
import '../repositories/sim_repository.dart';
import '../repositories/sms_repository.dart';
import '../services/config_service.dart';
import '../services/logger_service.dart';
import '../services/platform_channel_service.dart';
import '../services/retry_manager.dart';
import '../services/sim_service.dart';
import '../services/sms_service.dart';
import '../services/token_service.dart';
import '../server/http_server.dart';
import '../utils/logger.dart';

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
  final tokenService = TokenService(config: configRepo, logger: getIt<Logger>());
  final configService =
      ConfigService(repository: configRepo, logger: getIt<Logger>());
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

  getIt.registerSingleton<PlatformChannelService>(platform);
  getIt.registerSingleton<TokenService>(tokenService);
  getIt.registerSingleton<ConfigService>(configService);
  getIt.registerSingleton<SmsService>(smsService);
  getIt.registerSingleton<SimService>(simService);
  getIt.registerSingleton<RetryManager>(retryManager);

  // HTTP server.
  final httpServer = HttpServerService(
    smsService: smsService,
    simService: simService,
    smsRepo: smsRepo,
    simRepo: simRepo,
    logsRepo: logsRepo,
    tokenService: tokenService,
    configService: configService,
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
  // Force FFI backend so tests run on the host machine.
  sqfliteFfiInit();
  DatabaseHelper.overrideFactory = databaseFactoryFfi;

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

  final tokenService =
      TokenService(config: configRepo, logger: logger);
  final configService = ConfigService(repository: configRepo, logger: logger);
  final smsService =
      SmsService(repository: smsRepo, platform: fakePlatform, logger: logger);
  final simService =
      SimService(repository: simRepo, platform: fakePlatform, logger: logger);
  final retryManager = RetryManager(
    smsService: smsService,
    repository: smsRepo,
    logger: logger,
  );
  getIt.registerSingleton<TokenService>(tokenService);
  getIt.registerSingleton<ConfigService>(configService);
  getIt.registerSingleton<SmsService>(smsService);
  getIt.registerSingleton<SimService>(simService);
  getIt.registerSingleton<RetryManager>(retryManager);

  final httpServer = HttpServerService(
    smsService: smsService,
    simService: simService,
    smsRepo: smsRepo,
    simRepo: simRepo,
    logsRepo: logsRepo,
    tokenService: tokenService,
    configService: configService,
    logger: logger,
  );
  getIt.registerSingleton<HttpServerService>(httpServer);
}

/// Resets the DI container between tests.
Future<void> resetGetIt() async {
  await getIt.reset();
}
