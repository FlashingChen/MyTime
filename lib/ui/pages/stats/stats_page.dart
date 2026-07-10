import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/widgets/ai_insight_view.dart';
import 'package:mytime/ui/pages/stats/widgets/bar_chart_view.dart';
import 'package:mytime/ui/pages/stats/widgets/pie_chart_view.dart';
import 'package:mytime/ui/pages/stats/widgets/summary_cards.dart';

/// Statistics page with proportion, trend, and AI insight tabs.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String _range = 'week';
  String _tab = 'pie';

  @override
  void initState() {
    super.initState();
    context.read<RecordsBloc>().add(LoadRecords());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Range selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  _RangeChip(label: '本日', active: _range == 'day', onTap: () => _onRangeChanged('day')),
                  const SizedBox(width: 4),
                  _RangeChip(label: '本周', active: _range == 'week', onTap: () => _onRangeChanged('week')),
                  const SizedBox(width: 4),
                  _RangeChip(label: '本月', active: _range == 'month', onTap: () => _onRangeChanged('month')),
                ],
              ),
            ),
            // Summary cards
            BlocBuilder<RecordsBloc, RecordsState>(
              builder: (context, state) {
                if (state is RecordsLoaded) {
                  return _buildSummaryCards(state.records);
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 12),
            // Tab bar
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  _TabButton(label: '占比', active: _tab == 'pie', onTap: () => setState(() => _tab = 'pie')),
                  _TabButton(label: '趋势', active: _tab == 'bar', onTap: () => setState(() => _tab = 'bar')),
                  _TabButton(label: 'AI 建议', active: _tab == 'ai', onTap: () => setState(() => _tab = 'ai')),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: BlocBuilder<RecordsBloc, RecordsState>(
                builder: (context, state) {
                  final allRecords = state is RecordsLoaded ? state.records : <TimeRecord>[];
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
                  final monthStart = DateTime(now.year, now.month, 1);

                  List<TimeRecord> records;
                  switch (_range) {
                    case 'day':
                      records = allRecords.where((r) => r.startTime.isAfter(todayStart)).toList();
                      break;
                    case 'month':
                      records = allRecords.where((r) => r.startTime.isAfter(monthStart)).toList();
                      break;
                    case 'week':
                    default:
                      records = allRecords.where((r) => r.startTime.isAfter(weekStart)).toList();
                      break;
                  }

                  switch (_tab) {
                    case 'pie': return PieChartView(records: records);
                    case 'bar': return BarChartView(records: records);
                    case 'ai': return AiInsightView(records: records);
                    default: return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRangeChanged(String range) {
    setState(() => _range = range);
    context.read<RecordsBloc>().add(LoadRecords());
  }

  Widget _buildSummaryCards(List<TimeRecord> records) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    // Filter based on range
    List<TimeRecord> currentRecords;
    List<TimeRecord> previousRecords;
    int daysElapsed;

    switch (_range) {
      case 'day':
        currentRecords = records.where((r) => r.startTime.isAfter(todayStart)).toList();
        previousRecords = records.where((r) => r.startTime.isAfter(yesterdayStart) && r.startTime.isBefore(todayStart)).toList();
        daysElapsed = 1;
        break;
      case 'month':
        currentRecords = records.where((r) => r.startTime.isAfter(monthStart)).toList();
        previousRecords = records.where((r) => r.startTime.isAfter(lastMonthStart) && r.startTime.isBefore(monthStart)).toList();
        daysElapsed = now.day;
        break;
      case 'week':
      default:
        currentRecords = records.where((r) => r.startTime.isAfter(weekStart)).toList();
        previousRecords = records.where((r) => r.startTime.isAfter(weekStart.subtract(const Duration(days: 7))) && r.startTime.isBefore(weekStart)).toList();
        daysElapsed = now.weekday;
        break;
    }

    final currentMinutes = currentRecords.fold<int>(0, (s, r) => s + r.duration.inMinutes);
    final previousMinutes = previousRecords.fold<int>(0, (s, r) => s + r.duration.inMinutes);
    final avgMinutes = daysElapsed > 0 ? (currentMinutes ~/ daysElapsed) : 0;
    final prevAvg = previousRecords.isNotEmpty ? (previousMinutes ~/ previousRecords.length) : 0;

    final changePct = previousMinutes > 0
        ? ((currentMinutes - previousMinutes) * 100 ~/ previousMinutes)
        : 0;

    final avgChangePct = prevAvg > 0
        ? ((avgMinutes - prevAvg) * 100 ~/ prevAvg)
        : 0;

    String fmt(int m) {
      final h = m ~/ 60;
      final rem = m % 60;
      if (h > 0) return '${h}h ${rem}m';
      return '${rem}m';
    }

    String pct(int v) {
      if (v >= 0) return '+$v%';
      return '$v%';
    }

    String l1, l2, l3;
    if (_range == 'day') {
      l1 = '今日'; l2 = '昨日'; l3 = '同比';
    } else if (_range == 'month') {
      l1 = '本月'; l2 = '日均'; l3 = '同比';
    } else {
      l1 = '本周'; l2 = '日均'; l3 = '同比';
    }

    return SummaryCards(
      label1: l1, value1: fmt(currentMinutes), change1: pct(changePct),
      label2: l2, value2: fmt(avgMinutes), change2: pct(avgChangePct),
      label3: l3, value3: fmt(previousMinutes), change3: '',
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RangeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryDark : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: active ? AppColors.primaryDark : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? AppColors.primaryDark : AppColors.textHint),
          ),
        ),
      ),
    );
  }
}
