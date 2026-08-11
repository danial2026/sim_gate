import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Line chart of SMS activity per hour over the last 24 hours.
class SmsActivityChart extends StatelessWidget {
  const SmsActivityChart({
    super.key,
    required this.data,
  });

  /// List of `(hour, count)` pairs (ascending by hour).
  final List<({DateTime hour, int count})> data;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].count.toDouble()));
    }
    final maxY = spots.isEmpty
        ? 1.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1);

    return Container(
      height: 160,
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
            'SMS ACTIVITY · 24H',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.successColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.successColor.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                minY: 0,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Donut chart showing Sent / Failed / Pending proportions.
class SuccessRateChart extends StatelessWidget {
  const SuccessRateChart({
    super.key,
    required this.sent,
    required this.failed,
    required this.pending,
  });

  final int sent;
  final int failed;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final total = sent + failed + pending;
    final sections = <PieChartSectionData>[];
    if (total == 0) {
      sections.add(PieChartSectionData(
        value: 1,
        color: AppTheme.dividerColor,
        radius: 36,
        showTitle: false,
      ));
    } else {
      if (sent > 0) {
        sections.add(PieChartSectionData(
          value: sent.toDouble(),
          color: AppTheme.successColor,
          radius: 36,
          title: '$sent',
          titleStyle: const TextStyle(
            color: AppTheme.backgroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ));
      }
      if (failed > 0) {
        sections.add(PieChartSectionData(
          value: failed.toDouble(),
          color: AppTheme.errorColor,
          radius: 36,
          title: '$failed',
          titleStyle: const TextStyle(
            color: AppTheme.backgroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ));
      }
      if (pending > 0) {
        sections.add(PieChartSectionData(
          value: pending.toDouble(),
          color: AppTheme.warningColor,
          radius: 36,
          title: '$pending',
          titleStyle: const TextStyle(
            color: AppTheme.backgroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ));
      }
    }
    final rate = total == 0 ? 0.0 : (sent / total) * 100;

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
            'SUCCESS RATE',
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
              SizedBox(
                width: 96,
                height: 96,
                child: PieChart(PieChartData(
                  sections: sections,
                  centerSpaceRadius: 24,
                  sectionsSpace: 2,
                )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: AppTheme.monoFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Legend(
                        color: AppTheme.successColor, label: 'Sent', value: sent),
                    _Legend(
                        color: AppTheme.errorColor, label: 'Failed', value: failed),
                    _Legend(
                        color: AppTheme.warningColor,
                        label: 'Pending',
                        value: pending),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          const Spacer(),
          Text('$value',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: AppTheme.monoFamily,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
