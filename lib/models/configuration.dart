import 'package:flutter/material.dart';

/// Application theme preference.
enum AppThemeMode { light, dark, system }

extension AppThemeModeName on AppThemeMode {
  String get name => super.toString().split('.').last;

  static AppThemeMode parse(String? value) {
    if (value == null) return AppThemeMode.system;
    return AppThemeMode.values.firstWhere(
      (m) => m.name == value.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }

  ThemeMode toMaterial() {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Aggregate configuration model loaded from SharedPreferences.
class AppConfiguration {
  AppConfiguration({
    this.serverIp = '0.0.0.0',
    this.serverPort = 3000,
    this.accessToken,
    this.tokenGeneratedAt,
    this.autoStartServer = false,
    this.logLevel = 'info',
    this.logRetentionDays = 30,
    this.maxLogEntries = 10000,
    this.appTheme = AppThemeMode.system,
    this.activeSimIds = const [],
  });

  String serverIp;
  int serverPort;
  String? accessToken;
  DateTime? tokenGeneratedAt;
  bool autoStartServer;
  String logLevel;
  int logRetentionDays;
  int maxLogEntries;
  AppThemeMode appTheme;
  List<String> activeSimIds;

  /// Builds a copy with the given overrides.
  AppConfiguration copyWith({
    String? serverIp,
    int? serverPort,
    String? accessToken,
    DateTime? tokenGeneratedAt,
    bool? autoStartServer,
    String? logLevel,
    int? logRetentionDays,
    int? maxLogEntries,
    AppThemeMode? appTheme,
    List<String>? activeSimIds,
  }) {
    return AppConfiguration(
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      accessToken: accessToken ?? this.accessToken,
      tokenGeneratedAt: tokenGeneratedAt ?? this.tokenGeneratedAt,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      logLevel: logLevel ?? this.logLevel,
      logRetentionDays: logRetentionDays ?? this.logRetentionDays,
      maxLogEntries: maxLogEntries ?? this.maxLogEntries,
      appTheme: appTheme ?? this.appTheme,
      activeSimIds: activeSimIds ?? this.activeSimIds,
    );
  }

  /// Full API URL, e.g. `http://0.0.0.0:3000/api`.
  String get apiUrl => 'http://$serverIp:$serverPort/api';

  /// API URL with the token embedded (for QR sharing).
  String get apiUrlWithToken => '$apiUrl?token=$accessToken';
}
