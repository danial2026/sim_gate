import 'package:shelf/shelf.dart';

import '../../repositories/logs_repository.dart';
import '../../services/config_service.dart';
import '../../utils/validators.dart';
import '../api_response.dart';

/// Configuration + log-retention PUT endpoints.
class ConfigHandler {
  ConfigHandler({
    required this.configService,
    required this.logsRepo,
  });

  final ConfigService configService;
  final LogsRepository logsRepo;

  /// `PUT /api/config/port`
  Future<Response> updatePort(Request request) async {
    final body = parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final port = (body['port'] as num?)?.toInt();
    if (!PortValidator.isValid(port)) {
      return ApiResponse.error(PortValidator.errorMessage(port) ?? 'Invalid port',
          status: 400);
    }
    try {
      await configService.updatePort(port!);
      return ApiResponse.ok({
        'newPort': port,
        'message': 'Port updated. Server will restart on next connection.',
        'warning': 'Update API endpoint URL in clients',
      });
    } catch (e) {
      return ApiResponse.error(e.toString(), status: 400);
    }
  }

  /// `PUT /api/config/ip`
  Future<Response> updateIp(Request request) async {
    final body = parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final ip = body['ip'] as String?;
    if (!IpValidator.isValid(ip)) {
      return ApiResponse.error('Invalid IP address', status: 400);
    }
    try {
      await configService.updateIp(ip!);
      return ApiResponse.ok({
        'newIP': ip,
        'message': 'IP updated. Server will use new address.',
        'warning': 'Update API endpoint URL in clients',
      });
    } catch (e) {
      return ApiResponse.error(e.toString(), status: 400);
    }
  }

  /// `PUT /api/logs/retention`
  Future<Response> updateRetention(Request request) async {
    final body = parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final days = (body['retentionDays'] as num?)?.toInt();
    final entries = (body['maxEntries'] as num?)?.toInt();
    if (days == null || days < 1) {
      return ApiResponse.error('retentionDays must be a positive integer',
          status: 400);
    }
    if (entries == null || entries < 1) {
      return ApiResponse.error('maxEntries must be a positive integer',
          status: 400);
    }
    final config = configService.load();
    final updated = config.copyWith(
      logRetentionDays: days,
      maxLogEntries: entries,
    );
    await configService.save(updated);
    return ApiResponse.ok({
      'retentionDays': days,
      'maxEntries': entries,
      'message': 'Log retention policy updated',
    });
  }
}
