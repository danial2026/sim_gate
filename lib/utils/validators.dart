import '../constants/app_constants.dart';

/// Phone number normalization & validation helpers.
class PhoneNumberValidator {
  PhoneNumberValidator._();

  /// Validates E.164-ish phone numbers. Accepts leading `+` and digits,
  /// length between 7 and 15 (E.164 max).
  static bool isValid(String? number) {
    if (number == null || number.trim().isEmpty) return false;
    final trimmed = number.trim();
    final pattern = RegExp(r'^\+?[0-9]{7,15}$');
    return pattern.hasMatch(trimmed);
  }

  /// Masks a phone number for display, e.g. `+1234567890` -> `+1234****7890`.
  static String mask(String number) {
    if (number.length <= 4) return number;
    if (number.length <= 8) {
      return '${number.substring(0, 2)}****${number.substring(number.length - 2)}';
    }
    final start = number.substring(0, 4);
    final end = number.substring(number.length - 4);
    return '$start****$end';
  }
}

/// Port validation logic shared by the setup form and the API PUT handler.
class PortValidator {
  PortValidator._();

  static bool isValid(int? port) {
    if (port == null) return false;
    return port >= AppConstants.minPort && port <= AppConstants.maxPort;
  }

  static String? errorMessage(int? port) {
    if (port == null) return 'Port is required';
    if (port < AppConstants.minPort || port > AppConstants.maxPort) {
      return 'Port must be between ${AppConstants.minPort} '
          'and ${AppConstants.maxPort}';
    }
    return null;
  }
}

/// Message content validation.
class MessageValidator {
  MessageValidator._();

  static bool isValid(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    return message.length <= AppConstants.maxMessageLength;
  }

  /// Returns the number of SMS segments needed for [message].
  static int segmentCount(String message) {
    if (message.isEmpty) return 0;
    return (message.length / AppConstants.smsSegmentLength).ceil();
  }
}

/// IP address validation. Accepts IPv4 and the `0.0.0.0` wildcard.
class IpValidator {
  IpValidator._();

  static bool isValid(String? ip) {
    if (ip == null || ip.trim().isEmpty) return false;
    final value = ip.trim();
    if (value == '0.0.0.0' || value == 'localhost') return true;
    final parts = value.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }
}
