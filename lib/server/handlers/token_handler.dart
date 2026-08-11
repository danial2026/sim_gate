import 'package:shelf/shelf.dart';

import '../../services/token_service.dart';
import '../api_response.dart';

/// Token regeneration endpoint.
class TokenHandler {
  TokenHandler(this._tokenService);
  final TokenService _tokenService;

  /// `POST /api/token/regenerate`
  Future<Response> regenerate(Request request) async {
    final newToken = await _tokenService.regenerate();
    return ApiResponse.ok({
      'newToken': newToken,
      'oldTokenInvalidatedAt': DateTime.now().toUtc().toIso8601String(),
      'message': 'New token generated. Old token is now invalid.',
      'warning': 'Update all clients with the new token immediately',
    });
  }
}
