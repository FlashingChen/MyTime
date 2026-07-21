import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

class WeekView extends StatelessWidget {
  final DateTime selectedDate;
  final List<TimeRecord> records;
  final ValueChanged<DateTime> onDayTap;

  const WeekView({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekData = _computeWeekData();
    final maxY = weekData.fold<double>(
      0,
      (m, d) => (d.total.inMinutes / 60) > m ? (d.total.inMinutes / 60) : m,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.22 : 0.04,
              ),
              blurRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY * 1.3 : 1,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final idx = response?.spot?.touchedBarGroupIndex ?? -1;
                  if (idx >= 0 && idx < weekData.length) {
                    onDayTap(weekData[idx].date);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = weekData[groupIndex];
                    final catId = _categoryAtRod(day, rodIndex);
                    final catName = catId != null
                        ? CategoryLookup.byId(context, catId).name
                        : '';
                    return BarTooltipItem(
                      '${day.label}\n$catName ${formatStatsDuration(
                        Duration(minutes: (rod.toY - rod.fromY).round() * 60),
                      )}',
                      TextStyle(
                        color: context.colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: weekData.indexed.map((entry) {
                final idx = entry.$1;
                final day = entry.$2;
                return BarChartGroupData(
                  x: idx,
                  barRods: _buildRods(context, day),
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= weekData.length) {
                        return const SizedBox.shrink();
                      }
                      final day = weekData[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            Text(
                              day.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${day.date.month}/${day.date.day}',
                              style: TextStyle(
                                fontSize: 9,
                                color: context.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
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

  List<_DayData> _computeWeekData() {
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    return List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      Duration total = Duration.zero;
      final categoryDurations = <String, Duration>{};
      for (final record in records) {
        final overlapStart =
            record.startTime.isAfter(dayStart) ? record.startTime : dayStart;
        final overlapEnd =
            record.endTime.isBefore(dayEnd) ? record.endTime : dayEnd;
        final d = overlapEnd.difference(overlapStart);
        if (d <= Duration.zero) continue;
        total += d;
        final key = record.categoryId ?? 'uncategorized';
        categoryDurations[key] =
            (categoryDurations[key] ?? Duration.zero) + d;
      }
      return _DayData(
        date: day,
        label: const ['一', '二', '三', '四', '五', '六', '日'][index],
        total: total,
        categoryDurations: categoryDurations,
      );
    });
  }

  List<BarChartRodData> _buildRods(BuildContext context, _DayData day) {
    final rods = <BarChartRodData>[];
    double cumulative = 0;
    final ids = day.categoryDurations.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      final catId = ids[i];
      final value = (day.categoryDurations[catId]?.inMinutes ?? 0) / 60;
      if (value <= 0) continue;
      final cat = CategoryLookup.byId(context, catId);
      final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      rods.add(
        BarChartRodData(
          fromY: cumulative,
          toY: cumulative + value,
          color: color.withValues(alpha: 0.85),
          width: 24,
          borderRadius: i == ids.length - 1
              ? const BorderRadius.vertical(top: Radius.circular(4))
              : BorderRadius.zero,
        ),
      );
      cumulative += value;
    }
    if (rods.isEmpty) {
      rods.add(
        BarChartRodData(
          toY: 0.01,
          color: Colors.transparent,
          width: 24,
        ),
      );
    }
    return rods;
  }

  String? _categoryAtRod(_DayData day, int rodIndex) {
    var idx = 0;
    for (final catId in day.categoryDurations.keys) {
      final value = day.categoryDurations[catId]?.inMinutes ?? 0;
      if (value > 0) {
        if (idx == rodIndex) return catId;
        idx++;
      }
    }
    return null;
  }
}

class _DayData {
  final DateTime date;
  final String label;
  final Duration total;
  final Map<String, Duration> categoryDurations;

  const _DayData({
    required this.date,
    required this.label,
    required this.total,
    required this.categoryDurations,
  });
}