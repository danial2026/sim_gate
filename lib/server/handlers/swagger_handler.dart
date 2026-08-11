import 'package:shelf/shelf.dart';

import '../../services/config_service.dart';
import '../../services/sim_service.dart';
import '../api_response.dart';
import '../swagger/swagger_spec.dart';
import '../swagger/swagger_ui.dart';

/// Serves the interactive API docs page and its OpenAPI specification.
///
/// Both routes are *public* (no auth) so a browser can load them without a
/// token — access is controlled by the `enableSwagger` config toggle instead.
/// When disabled, every request returns 404. When enabled, the spec embeds
/// live config values so every example reflects the real device state.
///
/// NOTE: the access token is deliberately NOT included in the spec. Because
/// these routes are public, embedding the token would let anyone on the
/// network steal it and bypass the API auth entirely. Users paste the token
/// manually (SimGate → Settings → Access Token).
class SwaggerHandler {
  SwaggerHandler({
    required this.configService,
    required this.simService,
    required this.appVersion,
  });

  final ConfigService configService;
  final SimService simService;
  final String appVersion;

  /// `GET /swagger.html` — interactive API docs.
  Future<Response> html(Request request) async {
    if (!_enabled()) return _disabledResponse();
    return Response.ok(
      SwaggerUi.html,
      headers: {'Content-Type': SwaggerUi.contentType},
    );
  }

  /// `GET /swagger.json` — OpenAPI 3.0 specification.
  Future<Response> spec(Request request) async {
    if (!_enabled()) return _disabledResponse();
    final config = configService.load();
    final sims = await simService.getAll();
    final spec = SwaggerSpecBuilder(
      config: config,
      sims: sims,
      appVersion: appVersion,
      serverOrigin: _serverOrigin(request),
    ).build();
    return Response.ok(
      encodeSpec(spec),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  bool _enabled() {
    final config = configService.load();
    return config.enableSwagger == true;
  }

  /// Scheme + host + port the client used to reach this server.
  ///
  /// shelf request URIs are relative (no scheme), so `request.url.origin`
  /// would throw. The `Host` header is guaranteed by HTTP/1.1 and reflects
  /// exactly what the browser address bar shows (e.g. `192.168.0.119:3000`).
  String _serverOrigin(Request request) {
    final host = request.headers['host'] ?? 'localhost';
    return 'http://$host';
  }

  Response _disabledResponse() => ApiResponse.error(
    'Swagger docs are disabled in app settings',
    status: 404,
  );
}
