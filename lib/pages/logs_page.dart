import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/sms_request.dart';
import '../providers/sms_provider.dart';
import '../utils/helpers.dart';
import '../utils/validators.dart';
import '../widgets/common/app_widgets.dart';

/// Page 6: Detailed SMS request logs with filtering & search.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  int _offset = 0;
  static const int _pageSize = 20;
  List<SmsRequest> _logs = const [];
  int _total = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool reset = true}) async {
    final provider = context.read<SmsProvider>();
    setState(() => _loading = true);
    final offset = reset ? 0 : _offset;
    final logs = await provider.query(
      limit: _pageSize,
      offset: offset,
      status: _statusFilter == 'all' ? null : _statusFilter,
      searchQuery: _searchController.text.isEmpty
          ? null
          : _searchController.text,
    );
    final total = await provider.totalCount(
      status: _statusFilter == 'all' ? null : _statusFilter,
      searchQuery: _searchController.text.isEmpty
          ? null
          : _searchController.text,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _total = total;
        _offset = offset;
        if (reset) _offset = 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimGateScaffold(
      title: 'Request Logs',
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: AppTheme.of(context).textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search recipient or message',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: AppTheme.of(context).textSecondary,
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.of(context).divider),
                ),
                child: DropdownButton<String>(
                  value: _statusFilter,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.of(context).surface,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'sent', child: Text('Sent')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                      value: 'retrying',
                      child: Text('Retrying'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _logs.isEmpty
                ? const Center(child: LoadingIndicator())
                : _logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs found',
                      style: TextStyle(
                        color: AppTheme.of(context).textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      return _LogTile(
                        request: log,
                        onRetry: log.canRetry
                            ? () async {
                                await context.read<SmsProvider>().cancel(
                                  log.requestId,
                                );
                                _load();
                              }
                            : null,
                      );
                    },
                  ),
          ),
          if (_logs.length < _total)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SecondaryButton(
                label: 'Load More',
                icon: Icons.expand_more,
                onPressed: () {
                  _offset += _pageSize;
                  _load(reset: false);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.request, this.onRetry});
  final SmsRequest request;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _ExpandableLogTile(request: request, onRetry: onRetry);
  }
}

class _ExpandableLogTile extends StatefulWidget {
  const _ExpandableLogTile({required this.request, this.onRetry});
  final SmsRequest request;
  final VoidCallback? onRetry;

  @override
  State<_ExpandableLogTile> createState() => _ExpandableLogTileState();
}

class _ExpandableLogTileState extends State<_ExpandableLogTile> {
  bool _expanded = false;

  Color _statusColor() {
    switch (widget.request.status) {
      case SmsStatus.sent:
        return AppTheme.successColor;
      case SmsStatus.failed:
        return AppTheme.errorColor;
      case SmsStatus.retrying:
        return AppTheme.warningColor;
      case SmsStatus.pending:
        return AppTheme.of(context).textSecondary;
      case SmsStatus.cancelled:
        return AppTheme.of(context).textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _statusColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PhoneNumberValidator.mask(r.recipient),
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontFamily: AppTheme.monoFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          r.messagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.of(context).textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          Formatters.formatRelative(r.createdAt),
                          style: TextStyle(
                            color: AppTheme.of(context).textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        r.status.label,
                        style: TextStyle(
                          color: _statusColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'retries: ${r.currentRetryCount}/${r.maxRetries}',
                        style: TextStyle(
                          color: AppTheme.of(context).textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.of(context).textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(16).copyWith(top: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.of(context).divider),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'Request ID', value: r.requestId),
                  _DetailRow(label: 'Recipient', value: r.recipient),
                  _DetailRow(label: 'Message', value: r.message),
                  _DetailRow(
                    label: 'Created',
                    value: Formatters.formatDateTime(r.createdAt),
                  ),
                  if (r.sentAt != null)
                    _DetailRow(
                      label: 'Sent',
                      value: Formatters.formatDateTime(r.sentAt!),
                    ),
                  if (r.lastError != null)
                    _DetailRow(label: 'Error', value: r.lastError!),
                  if (widget.onRetry != null) ...[
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: 'Retry',
                      icon: Icons.refresh,
                      onPressed: widget.onRetry,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontFamily: AppTheme.monoFamily,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
