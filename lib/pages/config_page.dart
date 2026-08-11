import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/config_provider.dart';
import '../providers/server_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    final server = context.watch<ServerProvider>();
    final running = server.isRunning;

    return SimGateScaffold(
      title: 'Server Configuration',
      body: ListView(
        children: [
          const Text(
            'Server Configuration',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the configuration before starting the API server.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
            valueColor:
                running ? AppTheme.successColor : AppTheme.textSecondary,
            trailing: running
                ? Text(
                    Formatters.formatDuration(server.uptime),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
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
                color: AppTheme.textSecondary,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _tokenVisible = !_tokenVisible),
            ),
          ),
          if (config.tokenGeneratedAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                'Generated ${Formatters.formatRelative(config.tokenGeneratedAt!)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
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
                if (mounted) {
                  Navigator.of(context).pushNamed('/api-endpoint');
                }
              }
            },
          ),
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
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textPrimary,
                    fontSize: 15,
                    fontFamily:
                        mono ? AppTheme.monoFamily : null,
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

// ignore: unused_element
ClipboardData _copy(String text) => ClipboardData(text: text);
