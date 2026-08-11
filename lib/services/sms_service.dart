import '../constants/app_constants.dart';
import '../models/sms_request.dart';
import '../repositories/sms_repository.dart';
import '../utils/logger.dart';
import '../utils/validators.dart';
import 'platform_channel_service.dart';

/// Coordinates SMS sending: validates input, persists a request, delegates to
/// the [PlatformChannelService], records the retry outcome, and updates status.
class SmsService {
  SmsService({
    required SmsRepository repository,
    required PlatformChannelService platform,
    Logger? logger,
  })  : _repo = repository,
        _platform = platform,
        _logger = logger ?? Logger();

  final SmsRepository _repo;
  final PlatformChannelService _platform;
  final Logger _logger;

  /// Queues a new SMS send. Returns the persisted [SmsRequest].
  ///
  /// Throws [ArgumentError] for invalid recipient/message/simId.
  Future<SmsRequest> queue({
    required String simId,
    required String recipient,
    required String message,
    int maxRetries = 3,
    SmsPriority priority = SmsPriority.normal,
    String? clientIp,
  }) async {
    if (simId.isEmpty) {
      throw ArgumentError('simId is required');
    }
    if (!PhoneNumberValidator.isValid(recipient)) {
      throw ArgumentError('Invalid recipient: $recipient');
    }
    if (!MessageValidator.isValid(message)) {
      throw ArgumentError(
          'Message must be 1-${AppConstants.maxMessageLength} chars');
    }
    final request = await _repo.create(
      simId: simId,
      recipient: recipient,
      message: message,
      maxRetries: maxRetries,
      priority: priority,
      clientIp: clientIp,
    );
    _logger.info(LogComponent.sms, 'SMS queued',
        details: {'requestId': request.requestId}, requestId: request.requestId);
    return request;
  }

  /// Attempts to send a request immediately via the platform channel.
  /// Updates the request status and records a retry attempt.
  Future<SmsRequest> attemptSend(SmsRequest request) async {
    final result = await _platform.sendSms(
      simId: request.simId,
      recipient: request.recipient,
      message: request.message,
    );
    final attempt = await _repo.recordRetry(
      request: request,
      success: result.success,
      errorMessage: result.errorMessage,
      errorCode: result.errorCode,
      responseTimeMs: result.responseTimeMs,
    );
    _logger.info(
      LogComponent.sms,
      result.success ? 'SMS sent' : 'SMS send failed',
      details: {
        'requestId': request.requestId,
        'attempt': attempt.attemptNumber,
        'error': result.errorMessage,
      },
      requestId: request.requestId,
    );
    return request;
  }

  /// Convenience: queue + immediate first attempt.
  Future<SmsRequest> sendNow({
    required String simId,
    required String recipient,
    required String message,
    int maxRetries = 3,
    String? clientIp,
  }) async {
    final request = await queue(
      simId: simId,
      recipient: recipient,
      message: message,
      maxRetries: maxRetries,
      clientIp: clientIp,
    );
    return attemptSend(request);
  }

  /// Cancels a pending/retrying request.
  Future<int> cancel(String requestId) async {
    _logger.info(LogComponent.sms, 'Cancelling SMS request',
        requestId: requestId);
    return _repo.cancel(requestId);
  }

  /// Returns the detailed JSON for the API `/api/sms/status` endpoint.
  Future<Map<String, dynamic>> detailedStatus(String requestId) =>
      _repo.detailedJson(requestId);
}
