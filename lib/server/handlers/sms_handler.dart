import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../constants/app_constants.dart';
import '../../models/sms_request.dart';
import '../../services/sms_service.dart';
import '../../utils/validators.dart';
import '../api_response.dart';

/// SMS endpoints: send, cancel, status, logs.
class SmsHandler {
  SmsHandler(this._sms);

  final SmsService _sms;

  /// Builds the router for `/sms/*` paths.
  Router get router {
    final r = Router();

    // POST /send -------------------------------------------------------------
    r.post('/send', _send);
    // POST /cancel ----------------------------------------------------------
    r.post('/cancel', _cancel);
    // GET /status ------------------------------------------------------------
    r.get('/status', _status);
    // GET /logs -------------------------------------------------------------
    r.get('/logs', _logs);

    return r;
  }

  /// `POST /api/sms/send`
  Future<Response> _send(Request request) async {
    final body = await parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final simId = body['simId'] as String?;
    final recipient = body['recipient'] as String?;
    final message = body['message'] as String?;
    final maxRetries = (body['maxRetries'] as num?)?.toInt() ??
        AppConstants.defaultMaxRetries;
    final priority = _parsePriority(body['priority'] as String?);

    if (simId == null || simId.isEmpty) {
      return ApiResponse.error('simId is required', status: 400);
    }
    if (!PhoneNumberValidator.isValid(recipient)) {
      return ApiResponse.error('Invalid recipient', status: 400);
    }
    if (!MessageValidator.isValid(message)) {
      return ApiResponse.error(
          'Message must be 1-${AppConstants.maxMessageLength} chars',
          status: 400);
    }
    if (maxRetries < 0 || maxRetries > AppConstants.maxAllowedRetries) {
      return ApiResponse.error('maxRetries must be 0-${AppConstants.maxAllowedRetries}',
          status: 400);
    }

    final clientIp = request.requestedUri.host;
    final smsRequest = await _sms.sendNow(
      simId: simId,
      recipient: recipient!,
      message: message!,
      maxRetries: maxRetries,
      clientIp: clientIp,
    );

    final status = smsRequest.status == SmsStatus.sent ? 'sent' : 'pending';
    return ApiResponse.ok({
      'requestId': smsRequest.requestId,
      'status': status,
      'simId': smsRequest.simId,
      'recipient': smsRequest.recipient,
      'messageLength': smsRequest.messageLength,
      'maxRetries': smsRequest.maxRetries,
      'createdAt': smsRequest.createdAt.toIso8601String(),
      'estimatedDeliveryTime': 30,
      'message': 'Request queued for sending',
    }, status: 200);
  }

  /// `POST /api/sms/cancel`
  Future<Response> _cancel(Request request) async {
    final body = await parseJsonBody(request);
    if (body == null) {
      return ApiResponse.error('Invalid JSON body', status: 400);
    }
    final requestId = body['requestId'] as String?;
    if (requestId == null || requestId.isEmpty) {
      return ApiResponse.error('requestId is required', status: 400);
    }
    final existing = await _sms.detailedStatus(requestId);
    final previousStatus = existing['status'] as String;
    if (previousStatus == 'sent') {
      return ApiResponse.error('Cannot cancel already sent SMS', status: 409);
    }
    final rows = await _sms.cancel(requestId);
    if (rows == 0) {
      return ApiResponse.error('Request not found or not cancellable',
          status: 404);
    }
    return ApiResponse.ok({
      'requestId': requestId,
      'previousStatus': previousStatus,
      'newStatus': 'cancelled',
      'cancelledAt': DateTime.now().toUtc().toIso8601String(),
      'message': 'SMS request cancelled successfully',
    });
  }

  /// `GET /api/sms/status?requestId=...&detailed=true`
  Future<Response> _status(Request request) async {
    final params = request.requestedUri.queryParameters;
    final requestId = params['requestId'];
    if (requestId == null || requestId.isEmpty) {
      return ApiResponse.error('requestId is required', status: 400);
    }
    final detailed = params['detailed'] == 'true';
    try {
      final json = await _sms.detailedStatus(requestId);
      if (detailed) return ApiResponse.ok(json);
      // Strip retry history for the non-detailed view.
      final compact = Map<String, dynamic>.from(json)
        ..remove('retryHistory')
        ..remove('message');
      return ApiResponse.ok(compact);
    } catch (_) {
      return ApiResponse.error('Request not found', status: 404);
    }
  }

  /// `GET /api/sms/logs`
  Future<Response> _logs(Request request) async {
    final params = request.requestedUri.queryParameters;
    final limit = int.tryParse(params['limit'] ?? '') ?? 20;
    final offset = int.tryParse(params['offset'] ?? '') ?? 0;
    final status = params['status'];
    final simId = params['simId'];
    final startDate = params['startDate'] != null
        ? DateTime.parse(params['startDate']!).toUtc()
        : null;
    final endDate = params['endDate'] != null
        ? DateTime.parse(params['endDate']!).toUtc()
        : null;
    final searchQuery = params['searchQuery'];

    final clampedLimit = limit.clamp(1, AppConstants.maxLogsPage);
    final logs = await _sms.repository.query(
      limit: clampedLimit,
      offset: offset,
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
    final total = await _sms.repository.totalCount(
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
    return ApiResponse.ok({
      'logs': logs.map((l) => l.toApiResponseJson()).toList(),
      'total': total,
      'limit': clampedLimit,
      'offset': offset,
    });
  }

  SmsPriority _parsePriority(String? value) {
    if (value == null) return SmsPriority.normal;
    return SmsPriority.values.firstWhere(
      (p) => p.name == value.toLowerCase(),
      orElse: () => SmsPriority.normal,
    );
  }
}
