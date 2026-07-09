import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/ui/pages/timeline/widgets/date_navigator.dart';
import 'package:mytime/ui/pages/timeline/widgets/timeline_card.dart';

/// Timeline page showing daily records on a vertical time axis.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  DateTime _selectedDate = DateTime.now();
  String _viewMode = 'day';

  @override
  void initState() {
    super.initState();
    context.read<RecordsBloc>().add(RecordsLoadedByDate(_selectedDate));
  }

  void _onDateChanged(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    context.read<RecordsBloc>().add(RecordsLoadedByDate(_selectedDate));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DateNavigator(
              date: _selectedDate,
              onPrev: () => _onDateChanged(-1),
              onNext: () => _onDateChanged(1),
            ),
            // View toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ViewToggle(label: '日视图', active: _viewMode == 'day', onTap: () => setState(() => _viewMode = 'day')),
                  const SizedBox(width: 4),
                  _ViewToggle(label: '周视图', active: _viewMode == 'week', onTap: () => setState(() => _viewMode = 'week')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BlocBuilder<RecordsBloc, RecordsState>(
                builder: (context, state) {
                  if (state is RecordsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is RecordsLoadSuccess) {
                    return _buildTimeline(state.records);
                  }
                  return const Center(child: Text('暂无记录', style: TextStyle(color: AppColors.textSecondary)));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List records) {
    const rangeStartHour = 8;
    const rangeEndHour = 22;
    const hourHeight = 60.0;
    final totalHours = rangeEndHour - rangeStartHour;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      child: SizedBox(
        height: totalHours * hourHeight,
        child: Stack(
          children: [
            // Time grid
            ...List.generate(totalHours + 1, (i) {
              final hour = rangeStartHour + i;
              return Positioned(
                top: i * hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: Container(height: 0, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider)))),
                    ),
                  ],
                ),
              );
            }),
            // Event cards
            ...records.map<Widget>((record) {
              final startMin = record.startTime.hour * 60 + record.startTime.minute;
              final endMin = record.endTime.hour * 60 + record.endTime.minute;
              final rangeStartMin = rangeStartHour * 60;
              final top = (startMin - rangeStartMin) / 60 * hourHeight;
              final height = (endMin - startMin) / 60 * hourHeight;
              return Positioned(
                top: top,
                left: 40,
                right: 0,
                height: height < 24 ? 24 : height,
                child: TimelineCard(record: record),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ViewToggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryDark : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
