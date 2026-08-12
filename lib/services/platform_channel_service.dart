import 'dart:async';

import 'package:flutter/services.dart';

import '../models/sim_card.dart';
import '../models/server_info.dart';
import '../utils/logger.dart';

/// Result of an SMS send attempt returned by the platform channel.
class SmsSendResult {
  SmsSendResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
    this.responseTimeMs,
  });

  final bool success;
  final String? errorCode;
  final String? errorMessage;
  final int? responseTimeMs;
}

/// Abstraction over the native Android platform channels.
///
/// In production this is backed by [MethodChannel]. In tests, a fake
/// implementation can be injected to avoid the platform plugin.
abstract class PlatformChannelService {
  /// Sends an SMS via [simId] to [recipient].
  Future<SmsSendResult> sendSms({
    required String simId,
    required String recipient,
    required String message,
  });

  /// Returns the SIM cards currently detected by the device.
  Future<List<SimCard>> detectSims();

  /// Returns the available network interfaces.
  Future<List<NetworkInterface>> networkInterfaces();

  /// Starts the Android foreground service that keeps the gateway process
  /// alive while the phone is locked or the app is backgrounded.
  Future<void> startForegroundService();

  /// Stops the Android foreground service.
  Future<void> stopForegroundService();

  /// Whether the app is exempt from battery optimization (Doze / Samsung
  /// app-sleeping), which the OS requires for reliable background running.
  Future<bool> isBatteryOptimizationIgnored();

  /// Prompts the system dialog to whitelist the app from battery optimization.
  Future<void> requestIgnoreBatteryOptimizations();

  /// Opens the battery settings page (Samsung Device Care when available).
  Future<bool> openAppBatterySettings();
}

/// [MethodChannel]-backed implementation.
class MethodChannelPlatformService implements PlatformChannelService {
  MethodChannelPlatformService({Logger? logger})
    : _logger = logger ?? Logger(),
      _channel = const MethodChannel('com.danials.sim_gate/platform');

  final Logger _logger;
  final MethodChannel _channel;

  @override
  Future<SmsSendResult> sendSms({
    required String simId,
    required String recipient,
    required String message,
  }) async {
    final sw = Stopwatch()..start();
    try {
      await _channel.invokeMethod('sendSms', {
        'simId': simId,
        'recipient': recipient,
        'message': message,
      });
      sw.stop();
      _logger.info(
        LogComponent.sms,
        'SMS sent via platform',
        details: {'simId': simId, 'recipient': recipient},
      );
      return SmsSendResult(
        success: true,
        responseTimeMs: sw.elapsedMilliseconds,
      );
    } on PlatformException catch (e) {
      sw.stop();
      _logger.error(
        LogComponent.sms,
        'Platform sendSms failed',
        error: e,
        stackTrace: StackTrace.current,
        details: {'simId': simId, 'recipient': recipient},
      );
      return SmsSendResult(
        success: false,
        errorCode: e.code,
        errorMessage: e.message ?? e.code,
        responseTimeMs: sw.elapsedMilliseconds,
      );
    }
  }

  @override
  Future<List<SimCard>> detectSims() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('detectSims');
      if (result == null) return const [];
      return result
          .cast<Map>()
          .map((m) => _parseSim(Map<String, dynamic>.from(m)))
          .toList();
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.sim,
        'detectSims failed',
        error: e,
        stackTrace: StackTrace.current,
      );
      return const [];
    }
  }

  @override
  Future<List<NetworkInterface>> networkInterfaces() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'networkInterfaces',
      );
      if (result == null) return const [];
      return result
          .cast<Map>()
          .map(
            (m) => NetworkInterface(
              name: m['name'] as String,
              address: m['address'] as String,
            ),
          )
          .toList();
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'networkInterfaces failed',
        error: e,
        stackTrace: StackTrace.current,
      );
      return const [];
    }
  }

  @override
  Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'startForegroundService failed',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  @override
  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'stopForegroundService failed',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') ??
          false;
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'isBatteryOptimizationIgnored failed',
        error: e,
        stackTrace: StackTrace.current,
      );
      return false;
    }
  }

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'requestIgnoreBatteryOptimizations failed',
        error: e,
        stackTrace: StackTrace.current,
      );
    }
  }

  @override
  Future<bool> openAppBatterySettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAppBatterySettings') ??
          false;
    } on PlatformException catch (e) {
      _logger.error(
        LogComponent.server,
        'openAppBatterySettings failed',
        error: e,
        stackTrace: StackTrace.current,
      );
      return false;
    }
  }

  SimCard _parseSim(Map<String, dynamic> m) {
    return SimCard(
      simId: m['simId'] as String,
      slotNumber: (m['slotNumber'] as num).toInt(),
      name:
          (m['name'] as String?) ??
          'SIM ${(m['slotNumber'] as num).toInt() + 1}',
      phoneNumber: m['phoneNumber'] as String?,
      carrier: m['carrier'] as String?,
      signalStrength: (m['signalStrength'] as num?)?.toInt() ?? 0,
      networkType: NetworkTypeName.parse(m['networkType'] as String?),
      isActive: (m['isActive'] as bool?) ?? true,
      isRoaming: (m['isRoaming'] as bool?) ?? false,
    );
  }
}

/// A no-op [PlatformChannelService] used in tests and desktop environments
/// where the native channel is unavailable.
///
/// [FakePlatformService] can be configured to return canned SIM lists and to
/// succeed/fail SMS sends deterministically.
class FakePlatformService implements PlatformChannelService {
  FakePlatformService({
    List<SimCard>? sims,
    List<NetworkInterface>? interfaces,
    bool sendSucceeds = true,
    Duration sendDelay = Duration.zero,
  }) : _sims = sims ?? const [],
       _interfaces = interfaces ?? const [],
       _sendSucceeds = sendSucceeds,
       _sendDelay = sendDelay;

  List<SimCard> _sims;
  List<NetworkInterface> _interfaces;
  bool _sendSucceeds;
  Duration _sendDelay;

  /// Records the last invocation's arguments for assertion in tests.
  Map<String, dynamic>? lastSendArgs;

  void setSims(List<SimCard> sims) => _sims = sims;
  void setInterfaces(List<NetworkInterface> ifaces) => _interfaces = ifaces;
  void setSendSucceeds(bool value) => _sendSucceeds = value;
  void setSendDelay(Duration d) => _sendDelay = d;

  @override
  Future<SmsSendResult> sendSms({
    required String simId,
    required String recipient,
    required String message,
  }) async {
    lastSendArgs = {'simId': simId, 'recipient': recipient, 'message': message};
    if (_sendDelay != Duration.zero) {
      await Future.delayed(_sendDelay);
    }
    return SmsSendResult(
      success: _sendSucceeds,
      errorMessage: _sendSucceeds ? null : 'SIM_NOT_READY',
      errorCode: _sendSucceeds ? null : 'sim_not_ready',
      responseTimeMs: _sendDelay.inMilliseconds,
    );
  }

  @override
  Future<List<SimCard>> detectSims() async => List.unmodifiable(_sims);

  @override
  Future<List<NetworkInterface>> networkInterfaces() async =>
      List.unmodifiable(_interfaces);

  /// Tracks foreground-service start/stop invocations for test assertions.
  bool foregroundServiceStarted = false;
  bool foregroundServiceStopped = false;

  /// Whether the fake reports the app as exempt from battery optimization.
  bool batteryOptimizationIgnored = false;

  /// True once the battery-optimization request/settings were opened.
  bool batteryRequested = false;
  bool batterySettingsOpened = false;

  @override
  Future<void> startForegroundService() async {
    foregroundServiceStarted = true;
    foregroundServiceStopped = false;
  }

  @override
  Future<void> stopForegroundService() async {
    foregroundServiceStopped = true;
    foregroundServiceStarted = false;
  }

  @override
  Future<bool> isBatteryOptimizationIgnored() async =>
      batteryOptimizationIgnored;

  @override
  Future<void> requestIgnoreBatteryOptimizations() async {
    batteryRequested = true;
    batteryOptimizationIgnored = true;
  }

  @override
  Future<bool> openAppBatterySettings() async {
    batterySettingsOpened = true;
    return true;
  }
}
