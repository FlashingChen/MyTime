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
    context.read<RecordsBloc>().add(RecordsLoaded());
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
                  _RangeChip(label: '本日', active: _range == 'day', onTap: () => setState(() => _range = 'day')),
                  const SizedBox(width: 4),
                  _RangeChip(label: '本周', active: _range == 'week', onTap: () => setState(() => _range = 'week')),
                  const SizedBox(width: 4),
                  _RangeChip(label: '本月', active: _range == 'month', onTap: () => setState(() => _range = 'month')),
                ],
              ),
            ),
            // Summary cards
            const SummaryCards(todayTotal: '4h 20m', weekTotal: '30h 30m', avgPerDay: '4h 21m', todayChange: '+12%', weekChange: '+5%', avgChange: '-2%'),
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
                  final records = state is RecordsLoadSuccess ? state.records : <TimeRecord>[];
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
