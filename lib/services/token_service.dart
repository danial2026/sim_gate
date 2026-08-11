import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../repositories/config_repository.dart';
import '../utils/logger.dart';

/// Generates, persists, and validates access tokens.
///
/// The token is a random 256-bit hex string (32 bytes) produced from a UUID v4
/// plus a SHA-256 digest. The token is generated once on first app launch and
/// never auto-regenerated afterwards, per the project document.
class TokenService {
  TokenService({
    required ConfigRepository config,
    Uuid? uuid,
    Logger? logger,
  })  : _config = config,
        _uuid = uuid ?? const Uuid(),
        _logger = logger ?? Logger();

  final ConfigRepository _config;
  final Uuid _uuid;
  final Logger _logger;

  /// Returns the current token, generating one if missing.
  Future<String> ensureToken() async {
    final config = _config.load();
    if (config.accessToken != null && config.accessToken!.isNotEmpty) {
      return config.accessToken!;
    }
    return regenerate();
  }

  /// Generates a new token, persists it, and returns the value.
  Future<String> regenerate() async {
    final raw = _uuid.v4() + _uuid.v4();
    final digest = sha256.convert(utf8.encode(raw));
    final token = digest.toString();
    final now = DateTime.now().toUtc();
    await _config.saveToken(token, now);
    _logger.info(LogComponent.auth, 'Access token regenerated',
        details: {'generatedAt': now.toIso8601String()});
    return token;
  }

  /// Validates a presented token against the stored one (constant-time-ish).
  bool validate(String? presented) {
    final stored = _config.load().accessToken;
    if (stored == null || presented == null) return false;
    if (stored.length != presented.length) return false;
    var same = true;
    for (var i = 0; i < stored.length; i++) {
      if (stored[i] != presented[i]) same = false;
    }
    return same;
  }

  /// Returns the timestamp the current token was generated at.
  DateTime? get generatedAt => _config.load().tokenGeneratedAt;

  /// Returns the token partially masked for display, e.g.
  /// `a1b2...c3d4`.
  String mask(String token, {int visible = 4}) {
    if (token.length <= visible * 2) return token;
    return '${token.substring(0, visible)}...${token.substring(token.length - visible)}';
  }
}
