import 'dart:convert';

import '../../constants/api_endpoints.dart';
import '../../constants/app_constants.dart';
import '../../models/configuration.dart';
import '../../models/sim_card.dart';

/// Builds the OpenAPI 3.0 document for the SimGate HTTP API.
///
/// The spec is generated at request time so every example value reflects the
/// live app state: the configured port/IP, the detected SIM cards (used as
/// `simId` examples), and the log retention settings.
///
/// The access token is intentionally never embedded (see SwaggerHandler).
class SwaggerSpecBuilder {
  SwaggerSpecBuilder({
    required this.config,
    required this.sims,
    required this.appVersion,
  });

  final AppConfiguration config;
  final List<SimCard> sims;
  final String appVersion;

  /// Builds the OpenAPI document.
  Map<String, dynamic> build() {
    final activeSims = sims.where((s) => s.isActive).toList();
    final simIds = sims.map((s) => s.simId).toList();
    final activeSimIds = activeSims.map((s) => s.simId).toList();
    final samplePhone = activeSims
        .where((s) => s.phoneNumber != null)
        .map((s) => s.phoneNumber!)
        .firstOrNull;
    final simIdEnum = activeSimIds.isNotEmpty
        ? activeSimIds
        : (simIds.isNotEmpty ? simIds : null);

    return {
      'openapi': '3.0.3',
      'info': {
        'title': 'SimGate SMS Gateway API',
        'description':
            'Self-hosted SMS gateway. All endpoints except '
            '`GET /api/health` require the access token sent as '
            '`Authorization: Bearer <token>`. Responses always use the '
            'envelope `{ "success": bool, "data": ..., "error": ..., '
            '"timestamp": ..., "requestId": ... }`.',
        'version': appVersion,
      },
      'servers': [
        {
          'url': '',
          'description':
              'Same origin as the SimGate server; paths already include '
              'the /api prefix',
        },
      ],
      'tags': [
        {'name': 'Health', 'description': 'Service liveness (no auth)'},
        {'name': 'SMS', 'description': 'Send, cancel, track and list SMS'},
        {'name': 'SIMs', 'description': 'SIM card discovery and activation'},
        {'name': 'Server', 'description': 'Server metadata and stats'},
        {'name': 'Token', 'description': 'Access token management'},
        {'name': 'Config', 'description': 'Server configuration'},
        {'name': 'Logs', 'description': 'Log retention policy'},
      ],
      'security': [
        {'bearerAuth': <String>[]},
      ],
      'components': {
        'securitySchemes': {
          'bearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'description':
                'Access token shown in the SimGate app settings page. '
                'Regenerate it from Settings → Access Token.',
          },
        },
        'schemas': {
          'ApiEnvelope': {
            'type': 'object',
            'properties': {
              'success': {'type': 'boolean'},
              'data': {'type': 'object'},
              'error': {'type': 'string'},
              'timestamp': {'type': 'string', 'format': 'date-time'},
              'requestId': {'type': 'string'},
            },
          },
          'SimCard': {
            'type': 'object',
            'properties': {
              'simId': {'type': 'string'},
              'slotNumber': {'type': 'integer'},
              'name': {'type': 'string'},
              'phoneNumber': {'type': 'string', 'nullable': true},
              'carrier': {'type': 'string', 'nullable': true},
              'signalStrength': {'type': 'integer'},
              'networkType': {'type': 'string'},
              'isActive': {'type': 'boolean'},
              'isRoaming': {'type': 'boolean'},
              'state': {'type': 'string'},
            },
          },
          'SendSmsRequest': {
            'type': 'object',
            'required': ['simId', 'recipient', 'message'],
            'properties': {
              'simId': _stringSchema(
                'SIM slot id to send from',
                enumValues: simIdEnum,
              ),
              'recipient': _stringSchema(
                'E.164 phone number, e.g. +1234567890',
                example: samplePhone ?? '+1234567890',
              ),
              'message': _stringSchema(
                'SMS text (1-${AppConstants.maxMessageLength} chars)',
                example: 'Hello from SimGate API',
              ),
              'maxRetries': {
                'type': 'integer',
                'minimum': 0,
                'maximum': AppConstants.maxAllowedRetries,
                'default': AppConstants.defaultMaxRetries,
                'example': AppConstants.defaultMaxRetries,
              },
              'priority': {
                'type': 'string',
                'enum': ['low', 'normal', 'high'],
                'default': 'normal',
                'example': 'normal',
              },
            },
          },
          'CancelSmsRequest': {
            'type': 'object',
            'required': ['requestId'],
            'properties': {
              'requestId': _stringSchema(
                'SMS request id returned by POST /api/sms/send',
                example: 'm2xjx9k1abc123',
              ),
            },
          },
          'ActivateSimRequest': {
            'type': 'object',
            'required': ['simId'],
            'properties': {
              'simId': _stringSchema(
                'SIM slot id to activate/deactivate',
                enumValues: simIdEnum,
              ),
              'activate': {'type': 'boolean', 'default': true, 'example': true},
            },
          },
          'UpdatePortRequest': {
            'type': 'object',
            'required': ['port'],
            'properties': {
              'port': {
                'type': 'integer',
                'minimum': AppConstants.minPort,
                'maximum': AppConstants.maxPort,
                'example': config.serverPort,
              },
            },
          },
          'UpdateIpRequest': {
            'type': 'object',
            'required': ['ip'],
            'properties': {
              'ip': _stringSchema(
                'IPv4 address the server should listen on',
                example: config.serverIp,
              ),
            },
          },
          'UpdateRetentionRequest': {
            'type': 'object',
            'required': ['retentionDays', 'maxEntries'],
            'properties': {
              'retentionDays': {
                'type': 'integer',
                'minimum': 1,
                'example': config.logRetentionDays,
              },
              'maxEntries': {
                'type': 'integer',
                'minimum': 1,
                'example': config.maxLogEntries,
              },
            },
          },
        },
      },
      'paths': {
        ApiEndpoints.health: _path(
          tag: 'Health',
          summary: 'Check service liveness',
          description: 'Public endpoint, no authentication required.',
          security: const <Map<String, dynamic>>[],
          operationId: 'health',
          responses: {
            '200': _envelopeResponse(
              'Server is running',
              example: {
                'status': 'running',
                'uptime': '0h 12m 34s',
                'version': appVersion,
              },
            ),
          },
        ),
        ApiEndpoints.serverInfo: _path(
          tag: 'Server',
          summary: 'Server info & statistics',
          operationId: 'serverInfo',
          responses: {
            '200': _envelopeResponse(
              'Server details, request counts, SIM stats',
              example: {
                'serverStatus': 'running',
                'listeningIp': config.serverIp,
                'listeningPort': config.serverPort,
                'uptime': '0h 12m 34s',
                'startTime': DateTime.now().toUtc().toIso8601String(),
                'version': appVersion,
                'activeSims': activeSims.length,
                'totalSims': sims.length,
                'databaseSize': '0 KB',
                'totalRequests': 42,
                'successfulRequests': 38,
                'failedRequests': 2,
                'pendingRequests': 2,
                'averageResponseTime': '12ms',
                'connectedClients': 1,
                'totalApiRequests': 42,
              },
            ),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.serverToken: _path(
          tag: 'Server',
          summary: 'Token metadata',
          description:
              'Returns when the access token was generated. '
              'The token value itself is never exposed.',
          operationId: 'serverToken',
          responses: {
            '200': _envelopeResponse(
              'Token metadata',
              example: {
                'generatedAt': DateTime.now().toUtc().toIso8601String(),
                'usageCount': 0,
              },
            ),
            '401': _unauthorizedResponse(),
            '404': _errorResponse('Token not initialized'),
          },
        ),
        ApiEndpoints.activeSims: _path(
          tag: 'SIMs',
          summary: 'List SIM cards',
          operationId: 'listSims',
          responses: {
            '200': _envelopeResponse(
              'All detected SIM cards',
              example: {
                'simCards': sims.map((s) => s.toApiJson()).toList(),
                'activeSIMCount': activeSims.length,
                'totalSIMCount': sims.length,
              },
            ),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.simsActivate: _path(
          tag: 'SIMs',
          summary: 'Activate or deactivate a SIM',
          operationId: 'activateSim',
          method: 'post',
          requestBody: _jsonBody('ActivateSimRequest', {
            'simId': simIdEnum?.firstOrNull ?? 'sim-0',
            'activate': true,
          }),
          responses: {
            '200': _envelopeResponse(
              'SIM state changed',
              example: {'simId': 'sim-0', 'isActive': true, 'message': '...'},
            ),
            '400': _errorResponse('simId is required'),
            '401': _unauthorizedResponse(),
            '409': _errorResponse('At least one SIM must remain active'),
          },
        ),
        ApiEndpoints.smsSend: _path(
          tag: 'SMS',
          summary: 'Send an SMS',
          operationId: 'sendSms',
          method: 'post',
          requestBody: _jsonBody('SendSmsRequest', {
            'simId': simIdEnum?.firstOrNull ?? 'sim-0',
            'recipient': samplePhone ?? '+1234567890',
            'message': 'Hello from SimGate API',
            'maxRetries': AppConstants.defaultMaxRetries,
            'priority': 'normal',
          }),
          responses: {
            '200': _envelopeResponse(
              'Request queued or sent',
              example: {
                'requestId': 'm2xjx9k1abc123',
                'status': 'sent',
                'simId': 'sim-0',
                'recipient': '+1234567890',
                'messageLength': 22,
                'maxRetries': 3,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'estimatedDeliveryTime': 30,
                'message': 'Request queued for sending',
              },
            ),
            '400': _errorResponse('Invalid recipient'),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.smsCancel: _path(
          tag: 'SMS',
          summary: 'Cancel a pending SMS request',
          operationId: 'cancelSms',
          method: 'post',
          requestBody: _jsonBody('CancelSmsRequest', {
            'requestId': 'm2xjx9k1abc123',
          }),
          responses: {
            '200': _envelopeResponse(
              'Request cancelled',
              example: {
                'requestId': 'm2xjx9k1abc123',
                'previousStatus': 'pending',
                'newStatus': 'cancelled',
                'cancelledAt': DateTime.now().toUtc().toIso8601String(),
                'message': 'SMS request cancelled successfully',
              },
            ),
            '400': _errorResponse('requestId is required'),
            '401': _unauthorizedResponse(),
            '404': _errorResponse('Request not found or not cancellable'),
            '409': _errorResponse('Cannot cancel already sent SMS'),
          },
        ),
        ApiEndpoints.smsStatus: _path(
          tag: 'SMS',
          summary: 'Get SMS request status',
          operationId: 'smsStatus',
          parameters: [
            _queryParam(
              'requestId',
              'SMS request id',
              required: true,
              example: 'm2xjx9k1abc123',
            ),
            _queryParam(
              'detailed',
              'Include retry history and message body',
              schema: {'type': 'boolean', 'default': false, 'example': true},
            ),
          ],
          responses: {
            '200': _envelopeResponse(
              'Request status',
              example: {
                'requestId': 'm2xjx9k1abc123',
                'status': 'sent',
                'simId': 'sim-0',
                'recipient': '+1234567890',
                'messageLength': 22,
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'sentAt': DateTime.now().toUtc().toIso8601String(),
                'retryCount': 1,
                'maxRetries': 3,
                'lastError': null,
              },
            ),
            '400': _errorResponse('requestId is required'),
            '401': _unauthorizedResponse(),
            '404': _errorResponse('Request not found'),
          },
        ),
        ApiEndpoints.smsLogs: _path(
          tag: 'SMS',
          summary: 'List SMS request logs',
          operationId: 'smsLogs',
          parameters: [
            _queryParam(
              'limit',
              'Page size',
              schema: {
                'type': 'integer',
                'default': 20,
                'maximum': AppConstants.maxLogsPage,
                'example': 20,
              },
            ),
            _queryParam(
              'offset',
              'Pagination offset',
              schema: {'type': 'integer', 'default': 0, 'example': 0},
            ),
            _queryParam(
              'status',
              'Filter by status',
              schema: {
                'type': 'string',
                'enum': ['pending', 'retrying', 'sent', 'failed', 'cancelled'],
                'example': 'sent',
              },
            ),
            _queryParam(
              'simId',
              'Filter by SIM id',
              schema: _stringSchema('SIM id', enumValues: simIdEnum),
            ),
            _queryParam(
              'startDate',
              'Earliest createdAt (ISO-8601)',
              schema: {
                'type': 'string',
                'format': 'date-time',
                'example': '2026-01-01T00:00:00Z',
              },
            ),
            _queryParam(
              'endDate',
              'Latest createdAt (ISO-8601)',
              schema: {
                'type': 'string',
                'format': 'date-time',
                'example': '2026-12-31T23:59:59Z',
              },
            ),
            _queryParam(
              'searchQuery',
              'Search recipient or message',
              schema: {'type': 'string', 'example': 'hello'},
            ),
          ],
          responses: {
            '200': _envelopeResponse(
              'Paginated log entries',
              example: {
                'logs': <Map<String, dynamic>>[],
                'total': 0,
                'limit': 20,
                'offset': 0,
              },
            ),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.tokenRegenerate: _path(
          tag: 'Token',
          summary: 'Regenerate the access token',
          description:
              'Invalidates the current token immediately. Clients must be '
              'updated with the returned token.',
          operationId: 'regenerateToken',
          method: 'post',
          responses: {
            '200': _envelopeResponse(
              'New token issued',
              example: {
                'newToken': 'a1b2c3...',
                'oldTokenInvalidatedAt': DateTime.now()
                    .toUtc()
                    .toIso8601String(),
                'message': 'New token generated. Old token is now invalid.',
                'warning': 'Update all clients with the new token immediately',
              },
            ),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.configPort: _path(
          tag: 'Config',
          summary: 'Update the listening port',
          description: 'Takes effect after the server restarts.',
          operationId: 'updatePort',
          method: 'put',
          requestBody: _jsonBody('UpdatePortRequest', {
            'port': config.serverPort,
          }),
          responses: {
            '200': _envelopeResponse(
              'Port updated',
              example: {
                'newPort': config.serverPort,
                'message':
                    'Port updated. Server will restart on next '
                    'connection.',
                'warning': 'Update API endpoint URL in clients',
              },
            ),
            '400': _errorResponse('Port must be 1024-65535'),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.configIp: _path(
          tag: 'Config',
          summary: 'Update the listening IP',
          operationId: 'updateIp',
          method: 'put',
          requestBody: _jsonBody('UpdateIpRequest', {'ip': config.serverIp}),
          responses: {
            '200': _envelopeResponse(
              'IP updated',
              example: {
                'newIP': config.serverIp,
                'message': 'IP updated. Server will use new address.',
                'warning': 'Update API endpoint URL in clients',
              },
            ),
            '400': _errorResponse('Invalid IP address'),
            '401': _unauthorizedResponse(),
          },
        ),
        ApiEndpoints.logsRetention: _path(
          tag: 'Logs',
          summary: 'Update the log retention policy',
          operationId: 'updateRetention',
          method: 'put',
          requestBody: _jsonBody('UpdateRetentionRequest', {
            'retentionDays': config.logRetentionDays,
            'maxEntries': config.maxLogEntries,
          }),
          responses: {
            '200': _envelopeResponse(
              'Policy updated',
              example: {
                'retentionDays': config.logRetentionDays,
                'maxEntries': config.maxLogEntries,
                'message': 'Log retention policy updated',
              },
            ),
            '400': _errorResponse('retentionDays must be a positive integer'),
            '401': _unauthorizedResponse(),
          },
        ),
      },
    };
  }

  Map<String, dynamic> _path({
    required String tag,
    required String summary,
    required String operationId,
    required Map<String, dynamic> responses,
    List<Map<String, dynamic>>? parameters,
    Map<String, dynamic>? requestBody,
    String method = 'get',
    String? description,
    List<Map<String, dynamic>>? security,
  }) {
    final op = <String, dynamic>{
      'tags': [tag],
      'summary': summary,
      'operationId': operationId,
      if (description != null) 'description': description,
      if (parameters != null && parameters.isNotEmpty) 'parameters': parameters,
      if (requestBody != null) 'requestBody': requestBody,
      if (security != null) 'security': security,
      'responses': responses,
    };
    return {method: op};
  }

  Map<String, dynamic> _jsonBody(
    String schemaRef,
    Map<String, dynamic> example,
  ) {
    return {
      'required': true,
      'content': {
        'application/json': {
          'schema': {'\$ref': '#/components/schemas/$schemaRef'},
          'example': example,
        },
      },
    };
  }

  Map<String, dynamic> _queryParam(
    String name,
    String description, {
    bool required = false,
    Map<String, dynamic>? schema,
    Object? example,
  }) {
    return {
      'name': name,
      'in': 'query',
      'description': description,
      'required': required,
      'schema': schema ?? {'type': 'string'},
      if (example != null) 'example': example,
    };
  }

  Map<String, dynamic> _envelopeResponse(
    String description, {
    required Map<String, dynamic> example,
  }) {
    return {
      'description': description,
      'content': {
        'application/json': {
          'schema': {'\$ref': '#/components/schemas/ApiEnvelope'},
          'example': {
            'success': true,
            'data': example,
            'error': null,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'requestId': 'm2xjx9k1abc123',
          },
        },
      },
    };
  }

  Map<String, dynamic> _errorResponse(String message) {
    return {
      'description': message,
      'content': {
        'application/json': {
          'schema': {'\$ref': '#/components/schemas/ApiEnvelope'},
          'example': {
            'success': false,
            'data': null,
            'error': message,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
            'requestId': 'm2xjx9k1abc123',
          },
        },
      },
    };
  }

  Map<String, dynamic> _unauthorizedResponse() =>
      _errorResponse('Unauthorized: missing or invalid token');
}

Map<String, dynamic> _stringSchema(
  String description, {
  String? example,
  List<String>? enumValues,
}) {
  return {
    'type': 'string',
    'description': description,
    if (example != null) 'example': example,
    if (enumValues != null && enumValues.isNotEmpty) 'enum': enumValues,
  };
}

/// Pretty-prints the OpenAPI document for the `/swagger.json` response.
String encodeSpec(Map<String, dynamic> spec) =>
    const JsonEncoder.withIndent('  ').convert(spec);
