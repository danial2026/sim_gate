import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/configuration.dart';

/// Persists [AppConfiguration] via SharedPreferences.
///
/// SharedPreferences is used for configuration because it is fast, synchronous
/// to read after first load, and survives app restarts. The SQLite
/// `configuration` table exists as a backup/export option.
class ConfigRepository {
  ConfigRepository(this._prefs);

  final SharedPreferences _prefs;

  /// Loads the full configuration, applying defaults for missing keys.
  AppConfiguration load() {
    return AppConfiguration(
      serverIp:
          _prefs.getString(AppConstants.keyServerIp) ?? AppConstants.defaultIp,
      serverPort:
          _prefs.getInt(AppConstants.keyServerPort) ?? AppConstants.defaultPort,
      accessToken: _prefs.getString(AppConstants.keyAccessToken),
      tokenGeneratedAt: _parseDate(
        _prefs.getString(AppConstants.keyTokenGeneratedAt),
      ),
      autoStartServer: _prefs.getBool(AppConstants.keyAutoStartServer) ?? false,
      logLevel: _prefs.getString(AppConstants.keyLogLevel) ?? 'info',
      logRetentionDays:
          _prefs.getInt(AppConstants.keyLogRetentionDays) ??
          AppConstants.defaultLogRetentionDays,
      maxLogEntries:
          _prefs.getInt(AppConstants.keyMaxLogEntries) ??
          AppConstants.defaultMaxLogEntries,
      appTheme: AppThemeModeName.parse(
        _prefs.getString(AppConstants.keyAppTheme),
      ),
      activeSimIds: _decodeSimIds(_prefs.getString(AppConstants.keyActiveSims)),
      enableSwagger: _prefs.getBool(AppConstants.keyEnableSwagger) ?? false,
    );
  }

  /// Persists the whole configuration object.
  Future<void> save(AppConfiguration config) async {
    await _prefs.setString(AppConstants.keyServerIp, config.serverIp);
    await _prefs.setInt(AppConstants.keyServerPort, config.serverPort);
    await _prefs.setString(AppConstants.keyLogLevel, config.logLevel);
    await _prefs.setInt(
      AppConstants.keyLogRetentionDays,
      config.logRetentionDays,
    );
    await _prefs.setInt(AppConstants.keyMaxLogEntries, config.maxLogEntries);
    await _prefs.setString(AppConstants.keyAppTheme, config.appTheme.name);
    await _prefs.setBool(
      AppConstants.keyAutoStartServer,
      config.autoStartServer,
    );
    await _prefs.setString(
      AppConstants.keyActiveSims,
      jsonEncode(config.activeSimIds),
    );
    await _prefs.setBool(AppConstants.keyEnableSwagger, config.enableSwagger);
    if (config.accessToken != null) {
      await saveToken(
        config.accessToken!,
        config.tokenGeneratedAt ?? DateTime.now().toUtc(),
      );
    }
  }

  /// Persists just the access token and its generation timestamp.
  Future<void> saveToken(String token, DateTime generatedAt) async {
    await _prefs.setString(AppConstants.keyAccessToken, token);
    await _prefs.setString(
      AppConstants.keyTokenGeneratedAt,
      generatedAt.toIso8601String(),
    );
  }

  /// Persists the port only.
  Future<void> savePort(int port) =>
      _prefs.setInt(AppConstants.keyServerPort, port);

  /// Persists the IP only.
  Future<void> saveIp(String ip) =>
      _prefs.setString(AppConstants.keyServerIp, ip);

  /// Persists the auto-start flag.
  Future<void> saveAutoStart(bool value) =>
      _prefs.setBool(AppConstants.keyAutoStartServer, value);

  /// Persists the active SIM id list.
  Future<void> saveActiveSims(List<String> ids) =>
      _prefs.setString(AppConstants.keyActiveSims, jsonEncode(ids));

  /// Persists the swagger docs toggle.
  Future<void> saveSwaggerEnabled(bool value) =>
      _prefs.setBool(AppConstants.keyEnableSwagger, value);

  DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.parse(value).toUtc();

  List<String> _decodeSimIds(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    final list = jsonDecode(encoded);
    if (list is List) return list.map((e) => e.toString()).toList();
    return const [];
  }
}
