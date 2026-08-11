import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/blocs/stats/stats.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/ui/pages/stats/widgets/ai_insight_view.dart';
import 'package:mytime/ui/pages/stats/widgets/bar_chart_view.dart';
import 'package:mytime/ui/pages/stats/widgets/pie_chart_view.dart';
import 'package:mytime/ui/pages/stats/widgets/summary_cards.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/ui/pages/stats/widgets/category_filter_sheet.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';
import 'package:mytime/widgets/date_navigator.dart';

/// Statistics page with proportion, trend, and AI insight tabs.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final StatsBloc _statsBloc;
  List<String> _selectedCategoryIds = [];
  String _tab = 'pie';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _statsBloc = StatsBloc(context.read<RecordsBloc>());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initSelectedCategories();
  }

  @override
  void dispose() {
    unawaited(_statsBloc.close());
    super.dispose();
  }

  void _initSelectedCategories() {
    if (_selectedCategoryIds.isNotEmpty) return;
    final cats = CategoryLookup.all(context);
    _selectedCategoryIds = cats.map((c) => c.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _statsBloc,
      child: BlocBuilder<StatsBloc, StatsState>(
        builder: (context, state) {
          final metrics = state is StatsLoaded ? state.metrics : null;
          final range = metrics?.range ?? StatsRange.week;
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        _RangeChip(
                          label: '本日',
                          active: range == StatsRange.day,
                          onTap: () => _onRangeChanged(StatsRange.day),
                        ),
                        const SizedBox(width: 4),
                        _RangeChip(
                          label: '本周',
                          active: range == StatsRange.week,
                          onTap: () => _onRangeChanged(StatsRange.week),
                        ),
                        const SizedBox(width: 4),
                        _RangeChip(
                          label: '本月',
                          active: range == StatsRange.month,
                          onTap: () => _onRangeChanged(StatsRange.month),
                        ),
                      ],
                    ),
                  ),
                  if (range == StatsRange.day)
                    DateNavigator(
                      date: _selectedDate,
                      onPrev: () => _changeDay(-1),
                      onNext: () => _changeDay(1),
                    ),
                  if (metrics != null) _buildSummaryCards(metrics),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.colorScheme.outline),
                      ),
                    ),
                    child: Row(
                      children: [
                        _TabButton(
                          label: '占比',
                          active: _tab == 'pie',
                          onTap: () => setState(() => _tab = 'pie'),
                        ),
                        _TabButton(
                          label: '趋势',
                          active: _tab == 'bar',
                          onTap: () => setState(() => _tab = 'bar'),
                        ),
                        _TabButton(
                          label: 'AI 建议',
                          active: _tab == 'ai',
                          onTap: () => setState(() => _tab = 'ai'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildTabContent(metrics, range)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onRangeChanged(StatsRange range) {
    _statsBloc.add(StatsRangeChanged(range));
  }

  void _changeDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _statsBloc.add(StatsDayChanged(_selectedDate));
  }

  Widget _buildFilterButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showFilterSheet(context),
          icon: const Icon(Icons.tune, size: 16),
          label: Text('已选 ${_selectedCategoryIds.length} 个分类'),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) async {
    final cats = CategoryLookup.all(context);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (_) => CategoryFilterSheet(
        categories: cats,
        selectedIds: _selectedCategoryIds,
        onChanged: (v) => Navigator.of(context).pop(v),
      ),
    );
    if (result != null && mounted) {
      setState(
        () => _selectedCategoryIds
          ..clear()
          ..addAll(result),
      );
    }
  }

  Widget _buildTabContent(StatsMetrics? metrics, StatsRange range) {
    if (metrics == null) return const SizedBox.shrink();
    switch (_tab) {
      case 'pie':
        return PieChartView(categoryDurations: metrics.byCategory);
      case 'bar':
        return Column(
          children: [
            _buildFilterButton(context),
            Expanded(
              child: BarChartView(
                points: metrics.trend,
                selectedCategoryIds: _selectedCategoryIds,
              ),
            ),
          ],
        );
      case 'ai':
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) => AiInsightView(
            metrics: metrics,
            settings: settingsState is SettingsLoaded
                ? settingsState.settings
                : const AppSettings(),
            periodLabel: range == StatsRange.day
                ? (metrics.isToday
                      ? '今日'
                      : '${metrics.anchorDate.month}月${metrics.anchorDate.day}日')
                : range == StatsRange.week
                ? '本周'
                : '本月',
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSummaryCards(StatsMetrics metrics) {
    String format(Duration value) =>
        '${value.inHours}h ${value.inMinutes % 60}m';
    final change = metrics.previousTotal.inMinutes == 0
        ? 0
        : ((metrics.total.inMinutes - metrics.previousTotal.inMinutes) *
              100 ~/
              metrics.previousTotal.inMinutes);
    final isDay = metrics.range == StatsRange.day;
    final isToday = metrics.isToday;
    final changeStr = '${change >= 0 ? '+' : ''}$change%';
    return SummaryCards(
      label1: isDay
          ? (isToday ? '今日总时长' : '当日总时长')
          : metrics.range == StatsRange.week
          ? '本周总时长'
          : '本月总时长',
      value1: format(metrics.total),
      change1: changeStr,
      label2: isDay ? (isToday ? '昨日总时长' : '前一日总时长') : '日均',
      value2: format(isDay ? metrics.previousTotal : metrics.average),
      change2: changeStr,
      label3: isDay ? (isToday ? '较昨日变化' : '较前一日变化') : '较上一周期',
      value3: format(metrics.previousTotal),
      change3: changeStr,
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? context.colorScheme.primary
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active
                ? context.colorScheme.onPrimary
                : context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? context.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: active
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
