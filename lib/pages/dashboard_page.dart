import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/server_info.dart';
import '../providers/config_provider.dart';
import '../providers/server_provider.dart';
import '../providers/sim_provider.dart';
import '../providers/sms_provider.dart';
import '../utils/helpers.dart';
import '../widgets/common/app_widgets.dart';
import '../widgets/dashboard/charts.dart';
import '../widgets/dashboard/recent_logs.dart';
import '../widgets/dashboard/stats_card.dart';

/// Page 5: Real-time dashboard with stats, charts, and recent logs.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  List<({DateTime hour, int count})> _activity = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<SmsProvider>();
    await provider.refresh();
    final activity = await provider.hourlyActivity(hours: 24);
    if (mounted) setState(() => _activity = activity);
  }

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final stats = context.watch<SmsProvider>().stats;
    final sim = context.watch<SimProvider>();
    final running = server.isRunning;

    return SimGateScaffold(
      title: 'Dashboard',
      showBack: false,
      actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: _load),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 18),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
      ],
      body: RefreshIndicator(
        color: AppTheme.accentColor,
        onRefresh: _load,
        child: ListView(
          children: [
            _StatusCard(running: running, server: server),
            const SectionHeader('Quick Access'),
            _QuickAccess(
              onConfigure: () => Navigator.of(context).pushNamed('/config'),
              onSims: () => Navigator.of(context).pushNamed('/sim'),
              onApi: () => Navigator.of(context).pushNamed('/api-endpoint'),
              onSettings: () => Navigator.of(context).pushNamed('/settings'),
            ),
            const SectionHeader('Statistics'),
            _StatGrid(stats: stats),
            const SectionHeader('Recent'),
            RecentLogs(logs: stats.recentLogs),
            const SizedBox(height: 16),
            const SectionHeader('Activity'),
            SmsActivityChart(data: _activity),
            const SizedBox(height: 8),
            SuccessRateChart(
              sent: stats.totalSent,
              failed: stats.totalFailed,
              pending: stats.totalPending,
            ),
            const SizedBox(height: 8),
            _SignalGrid(sims: sim.sims),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'View Logs',
              icon: Icons.list_alt,
              onPressed: () => Navigator.of(context).pushNamed('/logs'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server status card with uptime, port, and connected clients.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.running, required this.server});
  final bool running;
  final ServerProvider server;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: running
            ? AppTheme.successColor.withValues(alpha: 0.05)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: running
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : AppTheme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: running ? AppTheme.successColor : AppTheme.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? 'Running' : 'Stopped',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${config.serverIp}:${config.serverPort}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (running)
            Text(
              Formatters.formatDuration(server.uptime),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontFamily: AppTheme.monoFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({
    required this.onConfigure,
    required this.onSims,
    required this.onApi,
    required this.onSettings,
  });
  final VoidCallback onConfigure;
  final VoidCallback onSims;
  final VoidCallback onApi;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickButton(
            icon: Icons.router_outlined,
            label: 'Configure',
            onTap: onConfigure,
          ),
          const SizedBox(width: 8),
          _QuickButton(
            icon: Icons.sim_card_outlined,
            label: 'SIM Cards',
            onTap: onSims,
          ),
          const SizedBox(width: 8),
          _QuickButton(
            icon: Icons.qr_code_outlined,
            label: 'API',
            onTap: onApi,
          ),
          const SizedBox(width: 8),
          _QuickButton(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textPrimary, size: 16),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        StatsCard(
          label: 'Sent',
          value: '${stats.totalSent}',
          color: AppTheme.successColor,
          icon: Icons.check_circle_outline,
        ),
        StatsCard(
          label: 'Failed',
          value: '${stats.totalFailed}',
          color: AppTheme.errorColor,
          icon: Icons.error_outline,
        ),
        StatsCard(
          label: 'Pending',
          value: '${stats.totalPending}',
          color: AppTheme.warningColor,
          icon: Icons.hourglass_empty,
        ),
        StatsCard(
          label: 'Avg Response',
          value: '${stats.averageResponseTimeMs}ms',
          icon: Icons.speed,
        ),
        StatsCard(
          label: 'Active SIMs',
          value: '${stats.activeSimCount}/${stats.totalSimCount}',
          icon: Icons.sim_card_outlined,
        ),
        StatsCard(
          label: 'Success Rate',
          value: '${stats.successRate.toStringAsFixed(1)}%',
          color: AppTheme.successColor,
          icon: Icons.trending_up,
        ),
      ],
    );
  }
}

class _SignalGrid extends StatelessWidget {
  const _SignalGrid({required this.sims});
  final List sims;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIGNAL STRENGTH',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 8 + 12.0 * i,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(
                          alpha: 0.4 + 0.15 * i,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
