import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Stacked bar chart showing daily time trends per category.
class BarChartView extends StatelessWidget {
  final List<StatsTrendPoint> points;
  final List<String> selectedCategoryIds;

  const BarChartView({
    super.key,
    required this.points,
    this.selectedCategoryIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(
      0,
      (m, p) {
        final total = selectedCategoryIds.fold<double>(
          0,
          (sum, id) => sum + (p.categoryDurations[id]?.inMinutes ?? 0) / 60,
        );
        return total > m ? total : m;
      },
    );

    return Padding(
      padding: const EdgeInsets.all(20),
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
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY * 1.2 : 1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[groupIndex];
                    final catId = _categoryAtRod(
                      point,
                      rodIndex,
                      selectedCategoryIds,
                    );
                    final catName = catId != null
                        ? CategoryLookup.byId(context, catId).name
                        : '';
                    return BarTooltipItem(
                      '${point.label}\n$catName ${formatStatsDuration(
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
              barGroups: points.indexed.map((entry) {
                final idx = entry.$1;
                final point = entry.$2;
                final rods = _buildRods(context, point);
                return BarChartGroupData(x: idx, barRods: rods);
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
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final point = points[idx];
                      final showLabel = points.length <= 7 || idx % 3 == 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Semantics(
                          label: '${point.label}，${formatStatsDuration(point.duration)}',
                          child: Text(
                            showLabel ? point.label : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

  List<BarChartRodData> _buildRods(BuildContext context, StatsTrendPoint point) {
    final rods = <BarChartRodData>[];
    double cumulative = 0;
    final activeIds = selectedCategoryIds.isEmpty
        ? point.categoryDurations.keys.toList()
        : selectedCategoryIds.where((id) => point.categoryDurations.containsKey(id)).toList();

    for (var i = 0; i < activeIds.length; i++) {
      final catId = activeIds[i];
      final value = (point.categoryDurations[catId]?.inMinutes ?? 0) / 60;
      if (value <= 0) continue;
      final cat = CategoryLookup.byId(context, catId);
      final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      rods.add(
        BarChartRodData(
          fromY: cumulative,
          toY: cumulative + value,
          color: color.withValues(alpha: 0.85),
          width: 16,
          borderRadius: i == activeIds.length - 1
              ? const BorderRadius.vertical(top: Radius.circular(4))
              : BorderRadius.zero,
        ),
      );
      cumulative += value;
    }
    return rods;
  }

  String? _categoryAtRod(
    StatsTrendPoint point,
    int rodIndex,
    List<String> selectedIds,
  ) {
    final activeIds = selectedIds.isEmpty
        ? point.categoryDurations.keys.toList()
        : selectedIds.where((id) => point.categoryDurations.containsKey(id)).toList();
    var idx = 0;
    for (final catId in activeIds) {
      final value = point.categoryDurations[catId]?.inMinutes ?? 0;
      if (value > 0) {
        if (idx == rodIndex) return catId;
        idx++;
      }
    }
    return null;
  }
}