import 'package:shelf/shelf.dart';

import '../../services/token_service.dart';
import '../../utils/logger.dart';
import '../api_response.dart';

/// Factory that builds the authentication middleware.
///
/// Endpoints registered in [publicPaths] skip auth (e.g. `/api/health`).
/// All other endpoints require a `Authorization: Bearer <token>` header that
/// matches the stored access token.
Middleware authMiddleware({
  required TokenService tokenService,
  required Set<String> publicPaths,
  Logger? logger,
}) {
  final log = logger ?? Logger();
  return (Handler innerHandler) {
    return (Request request) async {
      // CORS preflight requests never carry credentials.
      if (request.method == 'OPTIONS') {
        return innerHandler(request);
      }
      if (publicPaths.contains(request.url.path)) {
        return innerHandler(request);
      }
      final header = request.headers['authorization'];
      if (header == null || !header.startsWith('Bearer ')) {
        log.warning(LogComponent.auth, 'Missing auth header',
            details: {'path': request.url.path});
        return ApiResponse.error('Unauthorized: missing or invalid token',
            status: 401);
      }
      final presented = header.substring(7).trim();
      if (!tokenService.validate(presented)) {
        log.warning(LogComponent.auth, 'Invalid token',
            details: {'path': request.url.path});
        return ApiResponse.error('Unauthorized: invalid token', status: 401);
      }
      // Provide the validated request via context so handlers can use it.
      return innerHandler(
        request.change(
          context: {'validatedToken': presented},
        ),
      );
    };
  };
}
