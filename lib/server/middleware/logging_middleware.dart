import 'package:shelf/shelf.dart';

import '../../models/api_access_log.dart';
import '../../repositories/logs_repository.dart';
import '../../utils/logger.dart';
import '../api_response.dart';

/// Middleware that logs every request to the database and the console.
Middleware loggingMiddleware({
  required LogsRepository logsRepository,
  Logger? logger,
}) {
  final log = logger ?? Logger();
  return (Handler innerHandler) {
    return (Request request) async {
      final sw = Stopwatch()..start();
      int status = 500;
      String? error;
      try {
        final response = await innerHandler(request);
        status = response.statusCode;
        sw.stop();
        // Fire-and-forget the access log write.
        final requestId =
            request.context['validatedToken'] != null ? null : null;
        final entry = ApiAccessLog(
          id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
          requestId: requestId,
          clientIp: request.requestedUri.host,
          endpoint: '/${request.url.path}',
          method: request.method,
          statusCode: status,
          responseTimeMs: sw.elapsedMilliseconds,
          requestBodySize: request.contentLength,
          responseBodySize: int.tryParse(
              response.headers['content-length'] ?? ''),
          timestamp: DateTime.now().toUtc(),
          errorMessage: error,
        );
        // ignore: discarded_futures
        logsRepository.recordAccess(entry).catchError((Object e) {
          log.warning(LogComponent.api, 'Access log insert failed: $e');
        });
        log.info(LogComponent.api, '${request.method} /${request.url.path}',
            details: {'status': status, 'ms': sw.elapsedMilliseconds});
        return response;
      } catch (e, st) {
        sw.stop();
        error = e.toString();
        log.error(LogComponent.api,
            'Unhandled error handling ${request.method} /${request.url.path}',
            error: e, stackTrace: st);
        return ApiResponse.error('Internal server error',
            status: 500);
      }
    };
  };
}
