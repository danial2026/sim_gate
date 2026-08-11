import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/service_locator.dart';
import '../config/theme.dart';
import '../models/server_info.dart' as model;
import '../providers/config_provider.dart';
import '../providers/server_provider.dart';
import '../services/platform_channel_service.dart';
import '../widgets/common/app_widgets.dart';
import '../widgets/config/ip_selector.dart';
import '../widgets/config/port_input.dart';

/// Page 1: Configure the listening IP/port before starting the server.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _portController = TextEditingController();
  List<model.NetworkInterface> _interfaces = const [];
  String _selectedIp = '0.0.0.0';
  bool _loadingInterfaces = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConfigProvider>().config;
    _selectedIp = config.serverIp;
    _portController.text = '${config.serverPort}';
    _loadInterfaces();
  }

  /// Loads network interfaces from the platform channel.
  Future<void> _loadInterfaces() async {
    try {
      final platform = getIt<PlatformChannelService>();
      final ifaces = await platform.networkInterfaces();
      setState(() {
        _interfaces = ifaces;
        _loadingInterfaces = false;
      });
    } catch (_) {
      setState(() => _loadingInterfaces = false);
    }
  }

  /// Persists the form and navigates to the confirm page.
  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final provider = context.read<ConfigProvider>();
      await provider.updateIp(_selectedIp);
      await provider.updatePort(int.parse(_portController.text));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/config');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimGateScaffold(
      title: 'Configure Server',
      showBack: false,
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure Server',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the network interface and port the API will listen on.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SectionHeader('Network'),
                    IpSelector(
                      interfaces: _interfaces,
                      selected: _selectedIp,
                      onChanged: (v) => setState(() => _selectedIp = v),
                      isLoading: _loadingInterfaces,
                    ),
                    const SizedBox(height: 16),
                    PortInput(controller: _portController),
                    const SizedBox(height: 16),
                    _ServerStatusChip(),
                    const Spacer(),
                    PrimaryButton(
                      label: 'Continue',
                      isLoading: _saving,
                      icon: Icons.arrow_forward,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Cancel',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline status indicator showing whether the server is currently running.
class _ServerStatusChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();
    final running = server.isRunning;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: running ? AppTheme.successColor : AppTheme.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          running ? 'Server running' : 'Server stopped',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
