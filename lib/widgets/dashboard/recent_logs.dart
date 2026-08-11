import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/sms_request.dart';
import '../../utils/helpers.dart';

/// Compact list of recent SMS requests for the dashboard.
class RecentLogs extends StatelessWidget {
  const RecentLogs({
    super.key,
    required this.logs,
    this.onTap,
  });

  final List<SmsRequest> logs;
  final ValueChanged<SmsRequest>? onTap;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: const Center(
          child: Text(
            'No recent requests',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      children: logs
          .map((log) => _RecentLogTile(request: log, onTap: onTap))
          .toList(),
    );
  }
}

class _RecentLogTile extends StatelessWidget {
  const _RecentLogTile({required this.request, this.onTap});
  final SmsRequest request;
  final ValueChanged<SmsRequest>? onTap;

  Color _statusColor() {
    switch (request.status) {
      case SmsStatus.sent:
        return AppTheme.successColor;
      case SmsStatus.failed:
        return AppTheme.errorColor;
      case SmsStatus.retrying:
        return AppTheme.warningColor;
      case SmsStatus.pending:
        return AppTheme.textSecondary;
      case SmsStatus.cancelled:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(request),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: _statusColor(), shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.messagePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                  ),
                  Text(
                    Formatters.formatRelative(request.createdAt),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  request.status.label,
                  style: TextStyle(
                    color: _statusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'SIM ${request.simId.length <= 4 ? request.simId : request.simId.substring(0, 4)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontFamily: AppTheme.monoFamily,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
