import 'package:flutter/foundation.dart';

import '../models/server_info.dart';
import '../models/sms_request.dart';
import '../repositories/sim_repository.dart';
import '../repositories/sms_repository.dart';
import '../services/sms_service.dart';
import '../utils/logger.dart';

/// Aggregates SMS request state for the dashboard & logs page.
class SmsProvider extends ChangeNotifier {
  SmsProvider({
    required this.smsService,
    required this.smsRepository,
    required this.simRepository,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final SmsService smsService;
  final SmsRepository smsRepository;
  final SimRepository simRepository;
  final Logger _logger;

  List<SmsRequest> _recent = const [];
  List<SmsRequest> get recent => _recent;

  DashboardStats _stats = DashboardStats.empty();
  DashboardStats get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Reloads recent logs and aggregated stats.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      _recent = await smsRepository.recent(limit: 10);
      final counts = await smsRepository.countsByStatus();
      final avgMs = await smsRepository.averageResponseTimeMs();
      final active = await simRepository.activeCount();
      final total = await simRepository.totalCount();
      _stats = DashboardStats.fromCounts(
        counts: {
          for (final e in counts.entries)
            SmsStatus.fromName(e.key): e.value,
        },
        averageResponseTimeMs: avgMs,
        activeSimCount: active,
        totalSimCount: total,
        recentLogs: _recent,
      );
    } catch (e, st) {
      _logger.error(LogComponent.sms, 'Refresh failed',
          error: e, stackTrace: st);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns filtered/paginated logs (used by the Logs page).
  Future<List<SmsRequest>> query({
    int limit = 20,
    int offset = 0,
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return smsRepository.query(
      limit: limit,
      offset: offset,
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Returns the total count for the same filter.
  Future<int> totalCount({
    String? status,
    String? simId,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) {
    return smsRepository.totalCount(
      status: status,
      simId: simId,
      startDate: startDate,
      endDate: endDate,
      searchQuery: searchQuery,
    );
  }

  /// Cancels a request and refreshes.
  Future<void> cancel(String requestId) async {
    await smsService.cancel(requestId);
    await refresh();
  }

  /// Returns the retry history for a request.
  Future<List<dynamic>> history(String requestId) =>
      smsRepository.retryHistory(requestId);

  /// Hourly activity series for the dashboard chart.
  Future<List<({DateTime hour, int count})>> hourlyActivity({int hours = 24}) =>
      smsRepository.hourlyActivity(hours: hours);
}
