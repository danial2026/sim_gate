import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/sim_card.dart';
import 'signal_indicator.dart';

/// A single SIM card row in the SIM management list.
class SimCardItem extends StatelessWidget {
  const SimCardItem({super.key, required this.sim, required this.onToggle});

  final SimCard sim;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
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
              Icon(
                Icons.sim_card_outlined,
                color: sim.isActive
                    ? AppTheme.of(context).textPrimary
                    : AppTheme.of(context).textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sim.name,
                      style: TextStyle(
                        color: AppTheme.of(context).textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sim.carrier ?? 'Unknown carrier',
                      style: TextStyle(
                        color: AppTheme.of(context).textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SignalIndicator(strength: sim.signalStrength),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  sim.phoneNumber ?? 'No number',
                  style: TextStyle(
                    color: AppTheme.of(context).textPrimary,
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).divider,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sim.networkType.label,
                  style: TextStyle(
                    color: AppTheme.of(context).textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  sim.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: sim.isActive
                        ? AppTheme.successColor
                        : AppTheme.of(context).textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Switch.adaptive(value: sim.isActive, onChanged: onToggle),
            ],
          ),
        ],
      ),
    );
  }
}
