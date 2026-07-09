import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/time_record.dart';

/// Pie chart showing category time proportions.
class PieChartView extends StatelessWidget {
  final List<TimeRecord> records;

  const PieChartView({super.key, required this.records});

  Map<String, Duration> _aggregateByCategory() {
    final map = <String, Duration>{};
    for (final r in records) {
      map[r.categoryId] = (map[r.categoryId] ?? Duration.zero) + r.duration;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final aggregated = _aggregateByCategory();
    final totalSeconds = aggregated.values.fold<int>(0, (sum, d) => sum + d.inSeconds);

    if (totalSeconds == 0) {
      return const Center(child: Text('暂无数据', style: TextStyle(color: AppColors.textSecondary)));
    }

    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];

    for (final entry in aggregated.entries) {
      final cat = DefaultCategories.byId(entry.key);
      final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      final percentage = (entry.value.inSeconds / totalSeconds * 100).round();
      sections.add(PieChartSectionData(
        value: entry.value.inSeconds.toDouble(),
        color: catColor.withValues(alpha: 0.9),
        radius: 70,
        showTitle: false,
      ));
      legendItems.add(_LegendItem(
        color: catColor,
        name: cat.name,
        duration: _formatDuration(entry.value),
        percentage: '$percentage%',
      ));
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 3)],
            ),
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 38,
                  sectionsSpace: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              children: legendItems,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String name;
  final String duration;
  final String percentage;

  const _LegendItem({required this.color, required this.name, required this.duration, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          Text(duration, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          SizedBox(width: 32, child: Text(percentage, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
