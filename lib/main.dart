import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/service_locator.dart';
import 'config/theme.dart';
import 'models/configuration.dart';
import 'providers/config_provider.dart';
import 'providers/logs_provider.dart';
import 'providers/server_provider.dart';
import 'providers/sim_provider.dart';
import 'providers/sms_provider.dart';
import 'repositories/logs_repository.dart';
import 'repositories/sim_repository.dart';
import 'repositories/sms_repository.dart';
import 'services/config_service.dart';
import 'services/retry_manager.dart';
import 'services/sim_service.dart';
import 'services/sms_service.dart';
import 'services/token_service.dart';
import 'server/http_server.dart';
import 'utils/logger.dart';

// Page imports.
import 'pages/permissions_page.dart';
import 'pages/setup_page.dart';
import 'pages/config_page.dart';
import 'pages/api_endpoint_page.dart';
import 'pages/sim_cards_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/logs_page.dart';
import 'pages/settings_page.dart';

/// Entry point. Initializes DI and runs the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setup();
  runApp(const SimGateApp());
}

/// Root widget. Wires providers and the named-route navigator.
class SimGateApp extends StatelessWidget {
  const SimGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = getIt<ConfigService>();
    final tokenService = getIt<TokenService>();
    final simService = getIt<SimService>();
    final smsService = getIt<SmsService>();
    final smsRepo = getIt<SmsRepository>();
    final simRepo = getIt<SimRepository>();
    final logsRepo = getIt<LogsRepository>();
    final httpServer = getIt<HttpServerService>();
    final retryManager = getIt<RetryManager>();
    final logger = getIt<Logger>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConfigProvider(
            configService: configService,
            tokenService: tokenService,
            logger: logger,
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SimProvider(simService: simService, logger: logger),
        ),
        ChangeNotifierProvider(
          create: (_) => SmsProvider(
            smsService: smsService,
            smsRepository: smsRepo,
            simRepository: simRepo,
            logger: logger,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LogsProvider(logsRepository: logsRepo, logger: logger),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerProvider(
            httpServer: httpServer,
            retryManager: retryManager,
            logger: logger,
          ),
        ),
      ],
      child: Consumer<ConfigProvider>(
        builder: (context, config, _) => MaterialApp(
          title: 'SimGate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: config.config.appTheme.toMaterial(),
          initialRoute: '/',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/':
                return _fade(const PermissionsPage());
              case '/setup':
                return _fade(const SetupPage());
              case '/config':
                return _fade(const ConfigPage());
              case '/api-endpoint':
                return _fade(const ApiEndpointPage());
              case '/sim':
                return _fade(const SimCardsPage(inFlow: true));
              case '/dashboard':
                return _fade(const DashboardPage());
              case '/logs':
                return _fade(const LogsPage());
              case '/settings':
                return _fade(const SettingsPage());
            }
            return null;
          },
        ),
      ),
    );
  }

  /// Subtle fade-through transition used for all navigations.
  PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(opacity: anim, child: child);
      },
      transitionDuration: const Duration(milliseconds: 180),
    );
  }
}
