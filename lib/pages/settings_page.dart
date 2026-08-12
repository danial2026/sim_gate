import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../config/service_locator.dart';
import '../config/theme.dart';
import '../models/configuration.dart';
import '../providers/config_provider.dart';
import '../providers/logs_provider.dart';
import '../services/background_service.dart';
import '../utils/helpers.dart';
import '../utils/validators.dart';
import '../widgets/common/app_widgets.dart';

/// Page 7: App settings — token, server, logging, general, about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  bool _tokenVisible = false;

  /// Battery-optimization state: Samsung kills backgrounded apps unless the
  /// app is whitelisted (Device care → Battery → Background usage limits).
  bool _batteryIgnored = false;
  bool _batteryChecking = true;

  /// App version info loaded via package_info_plus at startup.
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageInfo();
    _refreshBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks the battery status when the user returns from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBatteryStatus();
    }
  }

  Future<void> _refreshBatteryStatus() async {
    final ignored = await getIt<BackgroundService>()
        .isBatteryOptimizationIgnored();
    if (!mounted) return;
    setState(() {
      _batteryIgnored = ignored;
      _batteryChecking = false;
    });
  }

  /// Shows the system dialog that whitelists SimGate from battery
  /// optimization (on Samsung this adds the app to "Never sleeping apps").
  Future<void> _fixBatteryOptimization() async {
    await getIt<BackgroundService>().requestBatteryOptimizationExemption();
    if (!mounted) return;
    _toast(
      context,
      'In the dialog, tap Allow so SimGate keeps running while locked',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _refreshBatteryStatus();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _packageInfo = info);
    } catch (_) {
      // Package info unavailable (e.g. in tests); keep the fallback version.
    }
  }

  /// Opens the token regeneration confirmation dialog.
  Future<void> _confirmRegenerate() async {
    final configProvider = context.read<ConfigProvider>();
    final regenerate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'WARNING',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        content: Text(
          'Generating a new token will invalidate the current token. '
          'All servers using the old token will need to be updated. '
          'This action cannot be undone.',
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
              'REGENERATE',
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
    if (regenerate == true) {
      await configProvider.regenerateToken();
      if (!mounted) return;
      _toast(context, 'Token regenerated');
    }
  }

  /// Dialog for changing the port with validation.
  Future<void> _editPort() async {
    final configProvider = context.read<ConfigProvider>();
    final config = configProvider.config;
    final controller = TextEditingController(text: '${config.serverPort}');
    final newPort = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('EDIT PORT'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: AppTheme.of(context).textPrimary,
            fontFamily: AppTheme.monoFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final port = int.tryParse(controller.text);
              if (PortValidator.isValid(port)) {
                Navigator.of(ctx).pop(port);
              } else {
                _toast(ctx, 'Port must be 1024-65535');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (newPort != null) {
      await configProvider.updatePort(newPort);
      if (!mounted) return;
      _toast(context, 'Port updated. API restart required.');
    }
  }

  /// Dialog for changing the IP with validation.
  Future<void> _editIp() async {
    final configProvider = context.read<ConfigProvider>();
    final config = configProvider.config;
    final controller = TextEditingController(text: config.serverIp);
    final newIp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('EDIT IP'),
        content: TextField(
          controller: controller,
          style: TextStyle(
            color: AppTheme.of(context).textPrimary,
            fontFamily: AppTheme.monoFamily,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (IpValidator.isValid(controller.text)) {
                Navigator.of(ctx).pop(controller.text);
              } else {
                _toast(ctx, 'Invalid IP address');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (newIp != null) {
      await configProvider.updateIp(newIp);
      if (!mounted) return;
      _toast(context, 'IP updated. API restart required.');
    }
  }

  /// Confirms and clears all logs.
  Future<void> _clearLogs() async {
    final logsProvider = context.read<LogsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CLEAR LOGS'),
        content: Text(
          'This will delete all app logs. This cannot be undone.',
          style: TextStyle(
            color: AppTheme.of(context).textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'CLEAR',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await logsProvider.clearAll();
      if (!mounted) return;
      _toast(context, 'Logs cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;

    return SimGateScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          const SectionHeader('Access Token'),
          _SettingTile(
            icon: Icons.key_outlined,
            title: 'Access Token',
            subtitle: _tokenVisible
                ? (config.accessToken ?? '—')
                : (config.accessToken ?? '—').length > 8
                ? '${config.accessToken!.substring(0, 8)}...${config.accessToken!.substring(config.accessToken!.length - 4)}'
                : (config.accessToken ?? '—'),
            mono: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _tokenVisible ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppTheme.of(context).textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _tokenVisible = !_tokenVisible),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: AppTheme.of(context).textSecondary,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: config.accessToken ?? ''),
                    );
                  },
                ),
              ],
            ),
          ),
          if (config.tokenGeneratedAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Generated ${Formatters.formatRelative(config.tokenGeneratedAt!)}',
                style: TextStyle(
                  color: AppTheme.of(context).textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          SecondaryButton(
            label: 'Regenerate Token',
            icon: Icons.refresh,
            onPressed: _confirmRegenerate,
          ),
          const SizedBox(height: 8),

          const SectionHeader('Server Settings'),
          _SettingTile(
            icon: Icons.cable_outlined,
            title: 'Port',
            subtitle: '${config.serverPort}',
            mono: true,
            trailing: TextButton(
              onPressed: _editPort,
              child: const Text(
                'EDIT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          _SettingTile(
            icon: Icons.router_outlined,
            title: 'IP Address',
            subtitle: config.serverIp,
            mono: true,
            trailing: TextButton(
              onPressed: _editIp,
              child: const Text(
                'EDIT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          _SettingTile(
            icon: Icons.play_circle_outline,
            title: 'Start API on app launch',
            subtitle: 'Requires server permission on first enable',
            trailing: Switch.adaptive(
              value: config.autoStartServer,
              onChanged: (v) async {
                await context.read<ConfigProvider>().updateAutoStart(v);
              },
            ),
          ),
          _SettingTile(
            icon: Icons.menu_book_outlined,
            title: 'API Docs (Swagger)',
            subtitle: config.enableSwagger
                ? 'Docs page is public on your network while enabled'
                : 'Serve interactive docs at /swagger.html',
            trailing: Switch.adaptive(
              value: config.enableSwagger,
              onChanged: (v) async {
                await context.read<ConfigProvider>().updateSwaggerEnabled(v);
                if (!context.mounted) return;
                _toast(
                  context,
                  v
                      ? 'Docs enabled: '
                            'http://${config.serverIp}:${config.serverPort}/swagger.html'
                      : 'API docs disabled',
                );
              },
            ),
          ),

          const SectionHeader('Background Service'),
          const _SettingTile(
            icon: Icons.notifications_active_outlined,
            title: 'Run while phone is locked',
            subtitle:
                'A persistent notification keeps the SMS gateway alive '
                'when the screen is locked or the app is backgrounded',
          ),
          _SettingTile(
            icon: Icons.battery_charging_full_outlined,
            title: 'Battery optimization',
            subtitle: _batteryChecking
                ? 'Checking…'
                : _batteryIgnored
                ? 'Exempt — the gateway keeps running when the screen locks'
                : 'Blocked — Samsung may stop the gateway while the phone '
                      'is locked',
            trailing: _batteryChecking
                ? null
                : _batteryIgnored
                ? const StatusBadge(
                    label: 'Exempt',
                    color: AppTheme.successColor,
                  )
                : TextButton(
                    onPressed: _fixBatteryOptimization,
                    child: const Text(
                      'FIX',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
          ),
          SecondaryButton(
            label: 'Open Battery Settings',
            icon: Icons.battery_saver_outlined,
            onPressed: () async {
              final opened = await getIt<BackgroundService>()
                  .openBatterySettings();
              if (!context.mounted) return;
              _toast(
                context,
                opened
                    ? 'Battery settings opened'
                    : 'Could not open battery settings',
              );
            },
          ),
          const SizedBox(height: 8),

          const SectionHeader('Logging'),
          _SettingTile(
            icon: Icons.receipt_long_outlined,
            title: 'Log Level',
            subtitle: config.logLevel.toUpperCase(),
            trailing: DropdownButton<String>(
              value: config.logLevel,
              underline: const SizedBox(),
              dropdownColor: AppTheme.of(context).surface,
              items: const [
                DropdownMenuItem(value: 'debug', child: Text('Debug')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
                DropdownMenuItem(value: 'warning', child: Text('Warning')),
                DropdownMenuItem(value: 'error', child: Text('Error')),
              ],
              onChanged: (v) {
                if (v == null) return;
                context.read<ConfigProvider>().updateLogSettings(
                  level: v,
                  retentionDays: config.logRetentionDays,
                  maxEntries: config.maxLogEntries,
                );
              },
            ),
          ),
          _SettingTile(
            icon: Icons.delete_outline,
            title: 'Clear All Logs',
            subtitle: 'Delete persisted app logs',
            trailing: TextButton(
              onPressed: _clearLogs,
              child: const Text(
                'CLEAR',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SecondaryButton(
            label: 'Export Logs',
            icon: Icons.file_download_outlined,
            onPressed: () => _toast(context, 'Log export coming soon'),
          ),
          const SizedBox(height: 8),

          const SectionHeader('General'),
          _SettingTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: config.appTheme.name.toUpperCase(),
            trailing: DropdownButton<AppThemeMode>(
              value: config.appTheme,
              underline: const SizedBox(),
              dropdownColor: AppTheme.of(context).surface,
              items: AppThemeMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<ConfigProvider>().updateTheme(v);
                }
              },
            ),
          ),

          const SectionHeader('About'),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'App Version',
            subtitle: _packageInfo == null
                ? 'Loading...'
                : '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
            mono: true,
          ),
          const _SettingTile(
            icon: Icons.verified_user_outlined,
            title: 'Permissions',
            subtitle: 'SMS · Phone · Notifications',
          ),
          const SizedBox(height: 16),
          Text(
            'SimGate v${_packageInfo?.version ?? getIt<AppInfo>().version} — '
            'Self-Hosted SMS API',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.of(context).textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          SecondaryButton(
            label: 'Developer',
            icon: Icons.code,
            onPressed: _openDeveloperSite,
          ),
        ],
      ),
    );
  }

  Future<void> _openDeveloperSite() async {
    final uri = Uri.parse('https://danials.org/');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _toast(context, 'Could not open danials.org');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.of(context).surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// A standard settings row: icon + title + subtitle + trailing widget.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.mono = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool mono;

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
                  title,
                  style: TextStyle(
                    color: AppTheme.of(context).textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 12,
                    fontFamily: mono ? AppTheme.monoFamily : null,
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
