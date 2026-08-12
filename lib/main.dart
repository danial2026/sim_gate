import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'services/background_service.dart';
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
  // Guarantee a token exists before the server can accept requests.
  await getIt<TokenService>().ensureToken();
  final config = getIt<ConfigService>().load();
  if (config.autoStartServer) {
    final httpServer = getIt<HttpServerService>();
    if (!httpServer.isRunning) {
      try {
        await httpServer.start(ip: config.serverIp, port: config.serverPort);
        getIt<RetryManager>().start();
        // Keep the gateway process alive once the phone locks.
        await getIt<BackgroundService>().start();
      } catch (e) {
        // Swallow startup failure; the user can start the API from the UI.
        getIt<Logger>().error(
          LogComponent.server,
          'Auto-start failed',
          error: e,
        );
      }
    }
  }
  runApp(const SimGateApp());
}

/// Root widget. Wires providers and the named-route navigator.
class SimGateApp extends StatefulWidget {
  const SimGateApp({super.key});

  @override
  State<SimGateApp> createState() => _SimGateAppState();
}

class _SimGateAppState extends State<SimGateApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _exitDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Android back button. Pops when there is a page to go back to; otherwise
  /// asks for confirmation before closing the app (applies to every page).
  @override
  Future<bool> didPopRoute() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return false;
    final popped = await navigator.maybePop();
    if (popped || _exitDialogOpen) return true;
    _exitDialogOpen = true;
    try {
      await _confirmExit();
    } finally {
      _exitDialogOpen = false;
    }
    return true;
  }

  /// Asks for confirmation before closing the app (root page back button).
  Future<void> _confirmExit() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    final exit = await showDialog<bool>(
      context: navigator.context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'CLOSE APP',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        content: Text(
          'Are you sure you want to close SimGate?\n'
          'The gateway keeps running in the background while the phone is '
          'locked. Closing the app does not stop it — use Stop API to stop it.',
          style: TextStyle(color: AppTheme.of(ctx).textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: AppTheme.of(ctx).textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'EXIT',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    if (exit == true) {
      await SystemNavigator.pop();
    }
  }

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
          navigatorKey: _navigatorKey,
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
