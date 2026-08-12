import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/service_locator.dart';
import '../config/theme.dart';
import '../providers/config_provider.dart';
import '../providers/server_provider.dart';
import '../services/background_service.dart';
import '../utils/helpers.dart';
import '../widgets/common/app_widgets.dart';

/// Page 2: Confirm the configuration and start the API server.
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  bool _tokenVisible = false;

  /// Battery-optimization status, checked once the server is running.
  bool? _batteryIgnored;

  Future<void> _refreshBatteryStatus() async {
    final ignored =
        await getIt<BackgroundService>().isBatteryOptimizationIgnored();
    if (!mounted) return;
    setState(() => _batteryIgnored = ignored);
  }

  /// Offers to whitelist the app from battery optimization right after the
  /// server starts. Critical on Samsung (app-sleeping kills background apps).
  Future<void> _maybePromptBatteryFix() async {
    final ignored =
        await getIt<BackgroundService>().isBatteryOptimizationIgnored();
    if (!mounted || ignored) {
      if (mounted) setState(() => _batteryIgnored = ignored);
      return;
    }
    _batteryIgnored = ignored;
    final fix = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'BACKGROUND RUNNING',
          style: TextStyle(
            color: AppTheme.warningColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        content: Text(
          'To keep the SMS gateway running while the phone is locked, '
          'SimGate needs to be exempt from battery optimization '
          '(Samsung may otherwise stop it in the background). '
          'Allow it now?',
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'LATER',
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ALLOW',
              style: TextStyle(
                color: AppTheme.successColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    if (fix == true) {
      await getIt<BackgroundService>().requestBatteryOptimizationExemption();
      await _refreshBatteryStatus();
    }
  }

  /// Asks the user to confirm before the system back button closes the app.
  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'CLOSE APP',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        content: Text(
          'Exiting will close the app. Any running API server will be stopped. Are you sure you want to exit?',
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'EXIT',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    if (exit == true && context.mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    final server = context.watch<ServerProvider>();
    final running = server.isRunning;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: SimGateScaffold(
        title: 'Server Configuration',
        showBack: false,
        body: ListView(
          children: [
            Text(
              'Server Configuration',
              style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review the configuration before starting the API server.',
              style: TextStyle(
                color: AppTheme.of(context).textSecondary,
                fontSize: 13,
              ),
            ),
            const SectionHeader('Settings'),
            _ConfigCard(
              icon: Icons.router_outlined,
              label: 'IP ADDRESS',
              value: config.serverIp,
            ),
            _ConfigCard(
              icon: Icons.cable_outlined,
              label: 'PORT',
              value: '${config.serverPort}',
            ),
            _ConfigCard(
              icon: Icons.power_settings_new_outlined,
              label: 'STATUS',
              value: running ? 'Running' : 'Stopped',
              valueColor: running
                  ? AppTheme.successColor
                  : AppTheme.of(context).textSecondary,
              trailing: running
                  ? Text(
                      Formatters.formatDuration(server.uptime),
                      style: TextStyle(
                        color: AppTheme.of(context).textSecondary,
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            _ConfigCard(
              icon: Icons.key_outlined,
              label: 'ACCESS TOKEN',
              value: _tokenVisible
                  ? (config.accessToken ?? '—')
                  : (config.accessToken == null
                        ? '—'
                        : '${config.accessToken!.substring(0, 6)}...${config.accessToken!.substring(config.accessToken!.length - 4)}'),
              mono: true,
              trailing: IconButton(
                icon: Icon(
                  _tokenVisible ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.of(context).textSecondary,
                  size: 18,
                ),
                onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
              ),
            ),
            if (config.tokenGeneratedAt != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  'Generated ${Formatters.formatRelative(config.tokenGeneratedAt!)}',
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: running ? 'Stop API' : 'Start API',
              icon: running ? Icons.stop : Icons.play_arrow,
              destructive: running,
              isLoading: server.isBusy,
              onPressed: () async {
                if (running) {
                  await server.stop();
                } else {
                  await server.start(config);
                  if (!context.mounted) return;
                  _maybePromptBatteryFix();
                  Navigator.of(context).pushNamed('/api-endpoint');
                }
              },
            ),
            if (running && _batteryIgnored == false)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Battery optimization may stop the gateway when the '
                        'screen locks. Fix it in Settings → Battery '
                        'optimization.',
                        style: TextStyle(
                          color: AppTheme.of(context).textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (running) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Open Dashboard',
                icon: Icons.dashboard_outlined,
                onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
              ),
            ],
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Edit Configuration',
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.of(context).pushNamed('/setup'),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Settings',
              icon: Icons.settings_outlined,
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only card with icon + uppercase label + value.
class _ConfigCard extends StatelessWidget {
  const _ConfigCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.of(context).textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.of(context).textPrimary,
                    fontSize: 15,
                    fontFamily: mono ? AppTheme.monoFamily : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
