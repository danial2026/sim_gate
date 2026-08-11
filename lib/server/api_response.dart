import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Standard JSON envelope used by every API response.
///
/// Matches the response format defined in `document.md`:
/// ```json
/// { "success": bool, "data": {}, "error": "...", "timestamp": "...", "requestId": "..." }
/// ```
class ApiResponse {
  ApiResponse._();

  /// Builds a successful JSON response.
  static Response ok(
    Map<String, dynamic> data, {
    String? requestId,
    int status = 200,
  }) {
    return _build(
      success: true,
      data: data,
      requestId: requestId,
      status: status,
    );
  }

  /// Builds an error JSON response.
  static Response error(
    String message, {
    String? requestId,
    int status = 400,
    Map<String, dynamic>? details,
  }) {
    return _build(
      success: false,
      error: message,
      requestId: requestId,
      status: status,
      extra: details,
    );
  }

  static Response _build({
    required bool success,
    Map<String, dynamic>? data,
    String? error,
    String? requestId,
    required int status,
    Map<String, dynamic>? extra,
  }) {
    final body = <String, dynamic>{
      'success': success,
      if (success) 'data': data,
      if (!success) 'error': error,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'requestId': requestId ?? _generateRequestId(),
      if (extra != null) ...extra,
    };
    return Response(
      status,
      body: jsonEncode(body),
      headers: const {'Content-Type': 'application/json'},
    );
  }

  static String _generateRequestId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

/// Parses a JSON request body into a [Map]. Returns `null` on parse failure.
///
/// Note: shelf requests are streamed, so this must be awaited.
Future<Map<String, dynamic>?> parseJsonBody(Request request) async {
  try {
    final body = await request.readAsString();
    if (body.isEmpty) return null;
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    return null;
  }
  return null;
}
