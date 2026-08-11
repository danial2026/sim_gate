import '../models/sim_card.dart';
import '../models/sms_request.dart';

/// Snapshot of server status used by the dashboard and `/api/server/info`.
class ServerInfo {
  ServerInfo({
    required this.serverStatus,
    required this.listeningIp,
    required this.listeningPort,
    required this.uptime,
    required this.startTime,
    required this.version,
    this.androidVersion,
    this.deviceName,
    this.deviceManufacturer,
    required this.activeSims,
    required this.totalSims,
    required this.databaseSize,
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.pendingRequests,
    required this.averageResponseTime,
    required this.connectedClients,
    this.batteryLevel,
    this.isCharging,
    this.networkConnected = true,
    this.networkType = 'WiFi',
  });

  final String serverStatus; // 'running' | 'stopped'
  final String listeningIp;
  final int listeningPort;
  final Duration uptime;
  final DateTime startTime;
  final String version;
  final String? androidVersion;
  final String? deviceName;
  final String? deviceManufacturer;
  final int activeSims;
  final int totalSims;
  final String databaseSize;
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int pendingRequests;
  final String averageResponseTime;
  final int connectedClients;
  final int? batteryLevel;
  final bool? isCharging;
  final bool networkConnected;
  final String networkType;

  /// Builds the JSON returned by `GET /api/server/info`.
  Map<String, dynamic> toApiJson() => {
        'serverStatus': serverStatus,
        'listeningIP': listeningIp,
        'listeningPort': listeningPort,
        'uptime': _formatDuration(uptime),
        'startTime': startTime.toIso8601String(),
        'version': version,
        'androidVersion': androidVersion,
        'deviceName': deviceName,
        'deviceManufacturer': deviceManufacturer,
        'activeSims': activeSims,
        'totalSims': totalSims,
        'databaseSize': databaseSize,
        'totalRequests': totalRequests,
        'successfulRequests': successfulRequests,
        'failedRequests': failedRequests,
        'pendingRequests': pendingRequests,
        'averageResponseTime': averageResponseTime,
        'connectedClients': connectedClients,
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
        'networkConnected': networkConnected,
        'networkType': networkType,
      };

  static String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Aggregated statistics rendered by the dashboard cards.
class DashboardStats {
  const DashboardStats({
    required this.totalSent,
    required this.totalFailed,
    required this.totalPending,
    required this.averageResponseTimeMs,
    required this.activeSimCount,
    required this.totalSimCount,
    required this.recentLogs,
  });

  final int totalSent;
  final int totalFailed;
  final int totalPending;
  final int averageResponseTimeMs;
  final int activeSimCount;
  final int totalSimCount;
  final List<SmsRequest> recentLogs;

  /// Empty-state factory used before the first refresh.
  factory DashboardStats.empty() => const DashboardStats(
        totalSent: 0,
        totalFailed: 0,
        totalPending: 0,
        averageResponseTimeMs: 0,
        activeSimCount: 0,
        totalSimCount: 0,
        recentLogs: [],
      );

  /// Builds a snapshot from aggregate counts plus recent requests.
  factory DashboardStats.fromCounts({
    required Map<SmsStatus, int> counts,
    required int averageResponseTimeMs,
    required int activeSimCount,
    required int totalSimCount,
    required List<SmsRequest> recentLogs,
  }) {
    return DashboardStats(
      totalSent: counts[SmsStatus.sent] ?? 0,
      totalFailed: counts[SmsStatus.failed] ?? 0,
      totalPending: (counts[SmsStatus.pending] ?? 0) +
          (counts[SmsStatus.retrying] ?? 0),
      averageResponseTimeMs: averageResponseTimeMs,
      activeSimCount: activeSimCount,
      totalSimCount: totalSimCount,
      recentLogs: recentLogs,
    );
  }

  /// Success rate as a percentage (0-100).
  double get successRate {
    final total = totalSent + totalFailed + totalPending;
    if (total == 0) return 0;
    return (totalSent / total) * 100;
  }
}

/// A network interface discovered by the platform channel.
class NetworkInterface {
  NetworkInterface({required this.name, required this.address});

  final String name; // e.g. "wlan0"
  final String address; // e.g. "192.168.1.10"

  @override
  String toString() => '$name ($address)';

  Map<String, dynamic> toJson() => {'name': name, 'address': address};
}

/// A SIM card plus its associated signal strength used by charts.
class SimSignal {
  const SimSignal({required this.sim, required this.signalStrength});

  final SimCard sim;
  final int signalStrength;
}
