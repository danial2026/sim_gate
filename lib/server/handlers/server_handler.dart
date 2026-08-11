import 'package:shelf/shelf.dart';

import '../../constants/app_constants.dart';
import '../../models/server_info.dart';
import '../../repositories/logs_repository.dart';
import '../../repositories/sms_repository.dart';
import '../../repositories/sim_repository.dart';
import '../../services/token_service.dart';
import '../../utils/helpers.dart';
import '../api_response.dart';

/// Server metadata & token info endpoints.
class ServerHandler {
  ServerHandler({
    required this.smsRepo,
    required this.simRepo,
    required this.logsRepo,
    required this.tokenService,
    required this.startTimeProvider,
    required this.serverIp,
    required this.serverPort,
  });

  final SmsRepository smsRepo;
  final SimRepository simRepo;
  final LogsRepository logsRepo;
  final TokenService tokenService;
  final DateTime Function() startTimeProvider;
  final String serverIp;
  final int serverPort;

  /// `GET /api/health` — no auth required.
  Response health(Request request) {
    final uptime = DateTime.now().toUtc().difference(startTimeProvider());
    return ApiResponse.ok({
      'status': 'running',
      'uptime': Formatters.formatDuration(uptime),
      'version': AppConstants.appVersion,
    });
  }

  /// `GET /api/server/info`
  Future<Response> info(Request request) async {
    final uptime = DateTime.now().toUtc().difference(startTimeProvider());
    final counts = await smsRepo.countsByStatus();
    final totalSims = await simRepo.totalCount();
    final activeSims = await simRepo.activeCount();
    final totalApi = await logsRepo.totalApiRequests();
    final clients = await logsRepo.connectedClients();
    final avgMs = await smsRepo.averageResponseTimeMs();
    final total = counts.values.fold(0, (a, b) => a + b);

    final info = ServerInfo(
      serverStatus: 'running',
      listeningIp: serverIp,
      listeningPort: serverPort,
      uptime: uptime,
      startTime: startTimeProvider(),
      version: AppConstants.appVersion,
      activeSims: activeSims,
      totalSims: totalSims,
      databaseSize: '0 KB',
      totalRequests: total,
      successfulRequests: counts['sent'] ?? 0,
      failedRequests: counts['failed'] ?? 0,
      pendingRequests: (counts['pending'] ?? 0) + (counts['retrying'] ?? 0),
      averageResponseTime: '${avgMs}ms',
      connectedClients: clients,
    );
    final json = info.toApiJson()
      ..removeWhere((k, v) => k == 'batteryLevel' && v == null)
      ..removeWhere((k, v) => k == 'isCharging' && v == null);
    json['totalApiRequests'] = totalApi;
    return ApiResponse.ok(json);
  }

  /// `GET /api/server/token` — token metadata without exposing the value.
  Response token(Request request) {
    final generatedAt = tokenService.generatedAt;
    if (generatedAt == null) {
      return ApiResponse.error('Token not initialized', status: 404);
    }
    return ApiResponse.ok({
      'generatedAt': generatedAt.toIso8601String(),
      'usageCount': 0,
    });
  }
}
