// ignore_for_file: implicit_call_tearoffs

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import '../constants/api_endpoints.dart';
import '../repositories/logs_repository.dart';
import '../repositories/sim_repository.dart';
import '../repositories/sms_repository.dart';
import '../services/config_service.dart';
import '../services/sim_service.dart';
import '../services/sms_service.dart';
import '../services/token_service.dart';
import '../utils/logger.dart';
import 'handlers/config_handler.dart';
import 'handlers/server_handler.dart';
import 'handlers/sim_handler.dart';
import 'handlers/sms_handler.dart';
import 'handlers/swagger_handler.dart';
import 'handlers/token_handler.dart';
import 'middleware/auth_middleware.dart';
import 'middleware/logging_middleware.dart';

/// Lifecycle state of the embedded HTTP server.
enum ServerState { stopped, starting, running, stopping }

/// Wraps the shelf HTTP server lifecycle.
///
/// Builds the router, applies auth + logging middleware, binds to [ip]:[port],
/// and exposes start/stop with status notifications via a [ValueNotifier].
class HttpServerService {
  HttpServerService({
    required this.smsService,
    required this.simService,
    required this.smsRepo,
    required this.simRepo,
    required this.logsRepo,
    required this.tokenService,
    required this.configService,
    required this.appVersion,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final SmsService smsService;
  final SimService simService;
  final SmsRepository smsRepo;
  final SimRepository simRepo;
  final LogsRepository logsRepo;
  final TokenService tokenService;
  final ConfigService configService;
  final String appVersion;
  final Logger _logger;

  HttpServer? _server;
  DateTime? _startTime;

  /// Current state observable used by providers.
  final _stateController = StreamController<ServerState>.broadcast();
  Stream<ServerState> get stateStream => _stateController.stream;
  ServerState _state = ServerState.stopped;
  ServerState get state => _state;
  DateTime? get startTime => _startTime;
  bool get isRunning => _server != null && _state == ServerState.running;

  /// Builds the request pipeline (router + middleware).
  shelf.Handler buildHandler() {
    final sms = SmsHandler(smsService);
    final sim = SimHandler(simService);
    final token = TokenHandler(tokenService);
    final config = ConfigHandler(
      configService: configService,
      logsRepo: logsRepo,
    );
    final boundIp = _server?.address.address;
    final boundPort = _server?.port;
    final server = ServerHandler(
      smsRepo: smsRepo,
      simRepo: simRepo,
      logsRepo: logsRepo,
      tokenService: tokenService,
      startTimeProvider: () => _startTime ?? DateTime.now().toUtc(),
      serverIp: boundIp ?? configService.load().serverIp,
      serverPort: boundPort ?? configService.load().serverPort,
      appVersion: appVersion,
    );
    final swagger = SwaggerHandler(
      configService: configService,
      simService: simService,
      appVersion: appVersion,
    );

    final router = Router();

    // Public health endpoint (no auth) ------------------------------------
    router.get(ApiEndpoints.health, server.health);

    // Public API docs (gated by the enableSwagger config toggle) ----------
    router.get('/swagger.html', swagger.html);
    router.get('/swagger.json', swagger.spec);

    // Authenticated subtree mounted under /api/* ---------------------------
    final authed = Router()
      ..mount('/sms', sms.router)
      ..mount('/sims', sim.router)
      ..mount('/server', serverRouter(server))
      ..mount('/token', tokenRouter(token))
      ..mount('/config', configRouter(config))
      ..mount('/logs', logsRetentionRouter(config));

    // Auth-protected paths: everything except /api/health and the docs.
    final public = {
      ApiEndpoints.health.substring(1), // strip leading '/'
      'swagger.html',
      'swagger.json',
    };
    router.mount('/api', authed);

    shelf.Handler handler = router;
    handler = _corsMiddleware(handler);
    handler = loggingMiddleware(logsRepository: logsRepo, logger: _logger)(
      handler,
    );
    handler = authMiddleware(
      tokenService: tokenService,
      publicPaths: public,
      logger: _logger,
    )(handler);

    // Wrap so the health route bypasses auth but still logs.
    return (shelf.Request request) async {
      // Strip query string for matching.
      final path = request.url.path;
      if (path == ApiEndpoints.health.substring(1)) {
        return _corsMiddleware(server.health)(request);
      }
      return handler(request);
    };
  }

  /// Starts the server bound to [ip]:[port]. Returns the bound address.
  Future<String> start({required String ip, required int port}) async {
    if (_state == ServerState.running || _state == ServerState.starting) {
      throw StateError('Server already running');
    }
    _setState(ServerState.starting);
    _startTime = DateTime.now().toUtc();
    try {
      final handler = buildHandler();
      _server = await io.serve(handler, ip, port);
      _setState(ServerState.running);
      // Port 0 => OS-assigned ephemeral port; report the actual bound one.
      final boundIp = _server!.address.address;
      final boundPort = _server!.port;
      _logger.info(
        LogComponent.server,
        'Server started',
        details: {'ip': boundIp, 'port': boundPort},
      );
      return 'http://$boundIp:$boundPort';
    } catch (e, st) {
      _setState(ServerState.stopped);
      _logger.error(
        LogComponent.server,
        'Failed to start server',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Stops the server if running.
  Future<void> stop() async {
    if (_server == null) {
      _setState(ServerState.stopped);
      return;
    }
    _setState(ServerState.stopping);
    await _server!.close(force: true);
    _server = null;
    _startTime = null;
    _setState(ServerState.stopped);
    _logger.info(LogComponent.server, 'Server stopped');
  }

  /// Permanently releases the state stream.
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }

  void _setState(ServerState s) {
    _state = s;
    _stateController.add(s);
  }

  // ---------------------------------------------------------------------------
  // CORS (allow local browser / curl clients)
  // ---------------------------------------------------------------------------
  shelf.Handler _corsMiddleware(shelf.Handler inner) {
    return (shelf.Request request) async {
      if (request.method == 'OPTIONS') {
        return shelf.Response(204, headers: _corsHeaders());
      }
      final response = await inner(request);
      return response.change(headers: _corsHeaders());
    };
  }

  Map<String, String> _corsHeaders() => const {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, Accept',
  };
}

// ---------------------------------------------------------------------------
// Small route builders for handlers that expose a single endpoint.
// ---------------------------------------------------------------------------

Router serverRouter(ServerHandler handler) {
  final r = Router();
  r.get('/info', handler.info);
  r.get('/token', handler.token);
  return r;
}

Router tokenRouter(TokenHandler handler) {
  final r = Router();
  r.post('/regenerate', handler.regenerate);
  return r;
}

Router configRouter(ConfigHandler handler) {
  final r = Router();
  r.put('/port', handler.updatePort);
  r.put('/ip', handler.updateIp);
  return r;
}

Router logsRetentionRouter(ConfigHandler handler) {
  final r = Router();
  r.put('/retention', handler.updateRetention);
  return r;
}
