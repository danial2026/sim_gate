/// Application-wide constants for the SimGate SMS gateway app.
///
/// Centralizes magic numbers, default values, and shared keys so that
/// services and UI can reference a single source of truth.
class AppConstants {
  AppConstants._(); // Prevent instantiation.

  // ---------------------------------------------------------------------------
  // App metadata
  // ---------------------------------------------------------------------------
  // NOTE: the app version and build number are NOT defined here. They are read
  // at runtime from `pubspec.yaml` via package_info_plus (see AppInfo) and are
  // also used for the Android APK versionName/versionCode.
  static const String appName = 'SimGate';

  // ---------------------------------------------------------------------------
  // Server defaults
  // ---------------------------------------------------------------------------
  static const String defaultIp = '0.0.0.0'; // Listen on all interfaces.
  static const int defaultPort = 3000;
  static const int minPort = 1024;
  static const int maxPort = 65535;

  // ---------------------------------------------------------------------------
  // SMS defaults
  // ---------------------------------------------------------------------------
  static const int defaultMaxRetries = 3;
  static const int maxAllowedRetries = 10;
  static const int defaultRetryDelayMs = 5000;
  static const int minRetryDelayMs = 1000;
  static const int maxRetryDelayMs = 60000;
  static const int maxMessageLength = 1600; // 10 SMS parts * 160 chars.
  static const int smsSegmentLength = 160;
  static const int retryManagerIntervalSeconds = 5;

  // ---------------------------------------------------------------------------
  // Dashboard / UI
  // ---------------------------------------------------------------------------
  static const int dashboardRefreshSeconds = 3;
  static const int recentLogsCount = 10;
  static const int logsPageSize = 20;
  static const int maxLogsPage = 100;

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------
  static const int defaultLogRetentionDays = 30;
  static const int defaultMaxLogEntries = 10000;

  // ---------------------------------------------------------------------------
  // SharedPreferences keys
  // ---------------------------------------------------------------------------
  static const String keyServerPort = 'server_port';
  static const String keyServerIp = 'server_ip';
  static const String keyAccessToken = 'access_token';
  static const String keyTokenGeneratedAt = 'token_generated_at';
  static const String keyAutoStartServer = 'auto_start_server';
  static const String keyLogLevel = 'log_level';
  static const String keyLogRetentionDays = 'log_retention_days';
  static const String keyMaxLogEntries = 'max_log_entries';
  static const String keyAppTheme = 'app_theme';
  static const String keyActiveSims = 'active_sims';
  static const String keyEnableSwagger = 'enable_swagger';

  // ---------------------------------------------------------------------------
  // Database
  // ---------------------------------------------------------------------------
  static const String databaseName = 'sim_gateway.db';
  static const int databaseVersion = 1;
}
