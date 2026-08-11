import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/theme.dart';
import '../widgets/common/app_widgets.dart';

/// Page 8: Requests the runtime permissions the gateway needs.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final Map<Permission, bool> _granted = {
    Permission.sms: false,
    Permission.phone: false,
    Permission.notification: false,
  };

  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  /// Reads the current permission statuses from the platform.
  Future<void> _refreshStatuses() async {
    try {
      final results = await Future.wait(_granted.keys.map((p) => p.status));
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < results.length; i++) {
          _granted[_granted.keys.elementAt(i)] = results[i].isGranted;
        }
        _checking = false;
      });
    } catch (_) {
      // Platform channel unavailable (e.g. during tests); degrade gracefully.
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  /// Requests a single permission and updates state.
  Future<void> _request(Permission p) async {
    try {
      final result = await p.request();
      if (!mounted) return;
      setState(() => _granted[p] = result.isGranted);
    } catch (_) {
      // Ignore platform failures; the card keeps showing "GRANT".
    }
  }

  /// Requests all permissions sequentially.
  Future<void> _requestAll() async {
    for (final p in _granted.keys) {
      try {
        final result = await p.request();
        if (mounted) _granted[p] = result.isGranted;
      } catch (_) {
        // Ignore platform failures.
      }
    }
    if (mounted) setState(() {});
  }

  bool get _allGranted => _granted.values.every((v) => v);

  @override
  Widget build(BuildContext context) {
    return SimGateScaffold(
      title: 'Permissions',
      showBack: false,
      body: _checking
          ? const Center(child: LoadingIndicator())
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grant Permissions',
                          style: TextStyle(
                            color: AppTheme.of(context).textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SimGate needs these permissions to send SMS, read SIM cards, '
                          'and serve API requests.',
                          style: TextStyle(
                            color: AppTheme.of(context).textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SectionHeader('Required'),
                        ..._granted.entries.map(
                          (e) => _PermissionCard(
                            permission: e.key,
                            granted: e.value,
                            onGrant: () => _request(e.key),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: _allGranted ? 'Continue' : 'Grant All',
                          onPressed: () async {
                            if (!_allGranted) {
                              await _requestAll();
                            }
                            if (!context.mounted) return;
                            if (_allGranted) {
                              _navigateNext(context);
                            }
                          },
                          icon: _allGranted
                              ? Icons.arrow_forward
                              : Icons.lock_open,
                        ),
                        const SizedBox(height: 12),
                        SecondaryButton(
                          label: 'Continue anyway',
                          icon: Icons.skip_next,
                          onPressed: () => _navigateNext(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Navigates to the setup page, replacing the stack.
  void _navigateNext(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/setup');
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.granted,
    required this.onGrant,
  });

  final Permission permission;
  final bool granted;
  final VoidCallback onGrant;

  String get _title {
    switch (permission) {
      case Permission.sms:
        return 'Send SMS';
      case Permission.phone:
        return 'Read Phone State';
      case Permission.notification:
        return 'Notifications';
      default:
        return permission.toString();
    }
  }

  String get _description {
    switch (permission) {
      case Permission.sms:
        return 'Required to send SMS messages via the gateway.';
      case Permission.phone:
        return 'Required to read SIM card information and signal state.';
      case Permission.notification:
        return 'Optional delivery and error notifications.';
      default:
        return 'Required for app functionality.';
    }
  }

  IconData get _icon {
    switch (permission) {
      case Permission.sms:
        return Icons.sms_outlined;
      case Permission.phone:
        return Icons.phone_android_outlined;
      case Permission.notification:
        return Icons.notifications_outlined;
      default:
        return Icons.security;
    }
  }

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
          Icon(_icon, color: AppTheme.of(context).textPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    color: AppTheme.of(context).textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _description,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const StatusBadge(
                  label: 'Granted',
                  color: AppTheme.successColor,
                )
              : TextButton(
                  onPressed: onGrant,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.of(context).accent,
                    side: BorderSide(color: AppTheme.of(context).subtleBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'GRANT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
        ],
      ),
    );
  }
}
