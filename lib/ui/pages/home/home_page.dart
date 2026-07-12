import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/blocs/timer/timer_event.dart';
import 'package:mytime/blocs/timer/timer_state.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/ui/pages/home/widgets/confirm_bottom_sheet.dart';
import 'package:mytime/ui/pages/home/widgets/recent_records_list.dart';
import 'package:mytime/ui/pages/home/widgets/timer_circle.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Home page with the core timer functionality.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isConfirmationSheetOpen = false;
  bool _isSavingRecord = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TimerBloc, TimerState>(
          listenWhen: (previous, current) =>
              current is TimerRunComplete && previous != current,
          listener: (context, state) {
            _showConfirmationSheet(context, state as TimerRunComplete);
          },
        ),
        BlocListener<RecordsBloc, RecordsState>(
          listener: (context, state) {
            if (!_isSavingRecord) return;
            if (state is RecordsLoaded) {
              _isSavingRecord = false;
              context.read<TimerBloc>().add(TimerReset());
              if (_isConfirmationSheetOpen) Navigator.of(context).pop();
            } else if (state is RecordsError) {
              _isSavingRecord = false;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
            }
          },
        ),
      ],
      child: BlocBuilder<TimerBloc, TimerState>(
        builder: (context, timerState) {
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: timerState is TimerRunInProgress ? 0 : 1,
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(
                        _formatDate(DateTime.now()),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(child: _buildTimerArea(context, timerState)),
                  ),
                  if (timerState is TimerInitial)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                      child: BlocBuilder<RecordsBloc, RecordsState>(
                        builder: (context, recordsState) {
                          if (recordsState is RecordsLoaded) {
                            return RecentRecordsList(
                              records: recordsState.records,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConfirmationSheet(BuildContext context, TimerRunComplete state) {
    if (_isConfirmationSheetOpen) return;
    _isConfirmationSheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        startTime: state.startTime,
        duration: state.duration,
        stoppedAt: state.stoppedAt,
        onConfirm: (record) {
          if (_isSavingRecord) return;
          _isSavingRecord = true;
          context.read<RecordsBloc>().add(RecordAdded(record));
        },
        onDiscard: () {
          context.read<TimerBloc>().add(TimerReset());
          Navigator.of(context).pop();
        },
      ),
    ).whenComplete(() {
      _isConfirmationSheetOpen = false;
    });
  }

  Widget _buildTimerArea(BuildContext context, TimerState state) {
    if (state is TimerInitial) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '00:00',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w700,
              color: context.colorScheme.onSurface,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击开始按钮开始计时',
            style: TextStyle(
              fontSize: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          _buildStartButton(context),
        ],
      );
    }

    if (state is TimerRunInProgress) {
      final progress = state.duration.inSeconds / 3600;
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: TimerCircle(
              duration: state.duration,
              progress: progress.clamp(0, 1),
            ),
          ),
          const SizedBox(height: 32),
          _buildStopButton(context),
        ],
      );
    }

    if (state is TimerRunComplete) {
      return const SizedBox.shrink();
    }

    return const SizedBox.shrink();
  }

  Widget _buildStartButton(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('start_timer_button'),
      onTap: () => context.read<TimerBloc>().add(TimerStarted()),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: context.colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(child: SvgIcons.play(size: 28)),
      ),
    );
  }

  Widget _buildStopButton(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('stop_timer_button'),
      onTap: () => context.read<TimerBloc>().add(TimerStopped()),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: SvgIcons.stop()),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '1月',
      '2月',
      '3月',
      '4月',
      '5月',
      '6月',
      '7月',
      '8月',
      '9月',
      '10月',
      '11月',
      '12月',
    ];
    return '${months[date.month - 1]}${date.day}日';
  }
}
