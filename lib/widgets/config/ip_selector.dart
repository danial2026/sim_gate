import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/server_info.dart';

/// Dropdown for selecting a network interface / IP to bind on.
class IpSelector extends StatelessWidget {
  const IpSelector({
    super.key,
    required this.interfaces,
    required this.selected,
    required this.onChanged,
    this.isLoading = false,
  });

  final List<NetworkInterface> interfaces;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // Build the list of options, always including the wildcard + localhost.
    final options = <NetworkInterface>[
      NetworkInterface(name: 'Any', address: '0.0.0.0'),
      NetworkInterface(name: 'Localhost', address: '127.0.0.1'),
      ...interfaces,
    ];
    final deduped = {
      for (final iface in options) iface.address: iface,
    }.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LISTENING ADDRESS',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: LoadingIndicator()),
                )
              : DropdownButton<String>(
                  value: selected,
                  isExpanded: true,
                  underline: const SizedBox(),
                  dropdownColor: AppTheme.surfaceColor,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 14,
                  ),
                  items: deduped
                      .map(
                        (iface) => DropdownMenuItem(
                          value: iface.address,
                          child: Text(
                            '${iface.name}  ·  ${iface.address}',
                            style: const TextStyle(
                              fontFamily: AppTheme.monoFamily,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
        ),
      ],
    );
  }
}

/// Re-exported indicator so this file stays self-contained.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    height: 24,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
