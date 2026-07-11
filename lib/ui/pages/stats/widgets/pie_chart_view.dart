import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';

/// Pie chart showing category time proportions and the selected category.
class PieChartView extends StatefulWidget {
  final List<TimeRecord> records;

  const PieChartView({super.key, required this.records});

  @override
  State<PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<PieChartView> {
  int? _selectedIndex;

  Map<String, Duration> _aggregateByCategory() {
    final map = <String, Duration>{};
    for (final record in widget.records) {
      final key = record.categoryId ?? 'uncategorized';
      map[key] = (map[key] ?? Duration.zero) + record.duration;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesBloc = _tryGetCategoriesBloc(context);
    if (categoriesBloc == null) {
      return _buildContent(context);
    }

    return BlocBuilder<CategoriesBloc, CategoriesState>(
      bloc: categoriesBloc,
      builder: (context, _) => _buildContent(context),
    );
  }

  CategoriesBloc? _tryGetCategoriesBloc(BuildContext context) {
    try {
      return context.read<CategoriesBloc>();
    } catch (_) {
      return null;
    }
  }

  Widget _buildContent(BuildContext context) {
    final aggregated = _aggregateByCategory();
    final totalSeconds = aggregated.values.fold<int>(
      0,
      (sum, duration) => sum + duration.inSeconds,
    );

    if (totalSeconds == 0) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final items = aggregated.entries
        .map((entry) {
          final category = CategoryLookup.byId(context, entry.key);
          return _PieItem(
            category: category.name,
            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            duration: entry.value,
            percentage: (entry.value.inSeconds / totalSeconds * 100).round(),
          );
        })
        .toList(growable: false);
    final selectedItem = _selectedIndex == null ? null : items[_selectedIndex!];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    label:
                        '分类饼图，${items.map((item) => '${item.category} ${item.percentage}%').join('，')}',
                    child: PieChart(
                      PieChartData(
                        sections: _sections(items),
                        centerSpaceRadius: 38,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;
                            final index =
                                response?.touchedSection?.touchedSectionIndex;
                            setState(() {
                              _selectedIndex =
                                  index == null ||
                                      index < 0 ||
                                      index >= items.length ||
                                      index == _selectedIndex
                                  ? null
                                  : index;
                            });
                          },
                        ),
                      ),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                  ),
                  if (selectedItem != null) _Tooltip(item: selectedItem),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              children: [
                for (final (index, item) in items.indexed)
                  _LegendItem(item: item, selected: index == _selectedIndex),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _sections(List<_PieItem> items) {
    return [
      for (final (index, item) in items.indexed)
        PieChartSectionData(
          value: item.duration.inSeconds.toDouble(),
          color: _selectedIndex == null
              ? item.color.withValues(alpha: 0.9)
              : index == _selectedIndex
              ? item.color
              : item.color.withValues(alpha: 0.5),
          radius: index == _selectedIndex ? 82 : 70,
          showTitle: false,
        ),
    ];
  }
}

class _PieItem {
  final String category;
  final Color color;
  final Duration duration;
  final int percentage;

  const _PieItem({
    required this.category,
    required this.color,
    required this.duration,
    required this.percentage,
  });
}

class _Tooltip extends StatelessWidget {
  final _PieItem item;

  const _Tooltip({required this.item});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        key: const ValueKey('pie_chart_tooltip'),
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.colorScheme.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorScheme.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, color: item.color),
                const SizedBox(width: 6),
                Text(
                  '${item.category} ${_formatDuration(item.duration)} ${item.percentage}%',
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final _PieItem item;
  final bool selected;

  const _LegendItem({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${item.category}，${_formatDuration(item.duration)}，${item.percentage}%',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              _formatDuration(item.duration),
              style: TextStyle(
                fontSize: 11,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text(
                '${item.percentage}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  return '${minutes}m';
}
