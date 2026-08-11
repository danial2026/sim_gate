import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// 4-bar signal strength indicator (0-4 bars).
class SignalIndicator extends StatelessWidget {
  const SignalIndicator({super.key, required this.strength, this.size = 14});
  final int strength;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bars = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final active = i < strength;
      final height = size * (0.5 + 0.15 * i);
      bars.add(
        Container(
          width: size * 0.22,
          height: height,
          decoration: BoxDecoration(
            color: active ? AppTheme.successColor : AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < bars.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          bars[i],
        ],
      ],
    );
  }
}
