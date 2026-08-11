import 'package:flutter/foundation.dart';

import '../models/app_log.dart';
import '../repositories/logs_repository.dart';
import '../utils/logger.dart';

/// Holds app log query state for the (future) detailed app-logs view.
class LogsProvider extends ChangeNotifier {
  LogsProvider({
    required this.logsRepository,
    Logger? logger,
  }) : _logger = logger ?? Logger();

  final LogsRepository logsRepository;
  final Logger _logger;

  List<AppLog> _logs = const [];
  List<AppLog> get logs => _logs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Loads the most recent logs.
  Future<void> load({int limit = 50}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _logs = await logsRepository.query(limit: limit);
    } catch (e, st) {
      _logger.error(LogComponent.database, 'Log load failed',
          error: e, stackTrace: st);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears all app + access logs.
  Future<void> clearAll() async {
    await logsRepository.deleteAll();
    await logsRepository.deleteAllAccess();
    _logs = const [];
    notifyListeners();
  }

  /// Purges logs older than [days].
  Future<void> purgeOlderThan(int days) async {
    await logsRepository.purgeOlderThan(Duration(days: days));
    await load();
  }
}
