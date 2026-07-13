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
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Statistics page with proportion, trend, and AI insight tabs.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final StatsBloc _statsBloc;
  String _tab = 'pie';

  @override
  void initState() {
    super.initState();
    _statsBloc = StatsBloc(context.read<RecordsBloc>());
  }

  @override
  void dispose() {
    unawaited(_statsBloc.close());
    super.dispose();
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

  Widget _buildTabContent(StatsMetrics? metrics, StatsRange range) {
    if (metrics == null) return const SizedBox.shrink();
    switch (_tab) {
      case 'pie':
        return PieChartView(categoryDurations: metrics.byCategory);
      case 'bar':
        return BarChartView(points: metrics.trend);
      case 'ai':
        return BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) => AiInsightView(
            metrics: metrics,
            settings: settingsState is SettingsLoaded
                ? settingsState.settings
                : const AppSettings(),
            periodLabel: range == StatsRange.day
                ? '今日'
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
    return SummaryCards(
      label1: isDay
          ? '今日总时长'
          : metrics.range == StatsRange.week
          ? '本周总时长'
          : '本月总时长',
      value1: format(metrics.total),
      change1: '${change >= 0 ? '+' : ''}$change%',
      label2: isDay ? '昨日总时长' : '日均',
      value2: format(isDay ? metrics.previousTotal : metrics.average),
      change2: '',
      label3: isDay ? '较昨日变化' : '较上一周期',
      value3: format(metrics.previousTotal),
      change3: '',
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
