import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// A single dashboard statistics card: large number + uppercase label.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final valueColor = color ?? AppTheme.of(context).textPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.of(context).divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppTheme.of(context).textSecondary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.monoFamily,
            ),
          ),
        ],
      ),
    );
  }
}
