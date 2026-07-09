import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/time_record.dart';

/// Bar chart showing daily time trends.
class BarChartView extends StatelessWidget {
  final List<TimeRecord> records;

  const BarChartView({super.key, required this.records});

  Map<int, double> _aggregateByDay() {
    final map = <int, double>{};
    for (final r in records) {
      final day = r.startTime.weekday;
      map[day] = (map[day] ?? 0) + r.duration.inMinutes / 60.0;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dayData = _aggregateByDay();
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final maxHours = dayData.values.fold<double>(0, (m, v) => v > m ? v : m);

    final spots = <FlSpot>[];
    for (int i = 1; i <= 7; i++) {
      spots.add(FlSpot(i.toDouble(), dayData[i] ?? 0));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)],
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxHours > 0 ? maxHours * 1.2 : 1,
              barGroups: spots.map((spot) {
                return BarChartGroupData(
                  x: spot.x.toInt(),
                  barRods: [
                    BarChartRodData(
                      toY: spot.y,
                      color: AppColors.accentStart.withValues(alpha: 0.85),
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt() - 1;
                      if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(dayLabels[idx], style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}
