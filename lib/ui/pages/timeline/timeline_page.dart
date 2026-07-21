import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/timeline_layout.dart';
import 'package:mytime/ui/pages/timeline/widgets/date_navigator.dart';
import 'package:mytime/ui/pages/timeline/widgets/timeline_card.dart';
import 'package:mytime/ui/pages/timeline/widgets/week_view.dart';

enum _TimelineViewMode { day, week }

/// Timeline page showing a selected day's records on a 24-hour vertical axis.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  static const _defaultHourHeight = 60.0;
  static const _minHourHeight = 30.0;
  static const _maxHourHeight = 120.0;
  static const _labelWidth = 40.0;
  static const _minCardHeight = 24.0;

  final ScrollController _scrollController = ScrollController();
  final Map<int, Offset> _activePointers = <int, Offset>{};
  DateTime _selectedDate = DateTime.now();
  _TimelineViewMode _viewMode = _TimelineViewMode.day;
  double _hourHeight = _defaultHourHeight;
  double _renderedHourHeight = _defaultHourHeight;
  double? _pinchDistance;
  int _zoomCorrectionGeneration = 0;
  Timer? _scaleFeedbackTimer;
  bool _showsScaleFeedback = false;

  @override
  void initState() {
    super.initState();
    context.read<RecordsBloc>().add(LoadRecords());
  }

  @override
  void dispose() {
    _scaleFeedbackTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDateChanged(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    _resetPinchBaseline();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length != 2 || _pinchDistance == null) return;

    final positions = _activePointers.values.toList(growable: false);
    final distance = (positions[0] - positions[1]).distance;
    if (distance == 0) return;

    final oldHourHeight = _hourHeight;
    final renderedHourHeight = _renderedHourHeight;
    final newHourHeight = (oldHourHeight * distance / _pinchDistance!).clamp(
      _minHourHeight,
      _maxHourHeight,
    );
    final localFocalY = (positions[0].dy + positions[1].dy) / 2;
    if (newHourHeight != oldHourHeight) {
      final correctionGeneration = ++_zoomCorrectionGeneration;
      final contentY = _scrollController.hasClients
          ? _scrollController.offset + localFocalY
          : null;
      setState(() => _hourHeight = newHourHeight);
      if (contentY != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              correctionGeneration != _zoomCorrectionGeneration ||
              !_scrollController.hasClients) {
            return;
          }
          _scrollController.jumpTo(
            ((contentY * (newHourHeight / renderedHourHeight)) - localFocalY)
                .clamp(0.0, _scrollController.position.maxScrollExtent)
                .toDouble(),
          );
        });
      }
    }
    _pinchDistance = distance;
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _resetPinchBaseline();
  }

  void _resetPinchBaseline() {
    if (_activePointers.length == 2) {
      final positions = _activePointers.values.toList(growable: false);
      _pinchDistance = (positions[0] - positions[1]).distance;
    } else {
      _pinchDistance = null;
    }
  }

  void _restoreDefaultScale() {
    setState(() {
      _hourHeight = _defaultHourHeight;
      _showsScaleFeedback = true;
    });
    _scaleFeedbackTimer?.cancel();
    _scaleFeedbackTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showsScaleFeedback = false);
    });
  }

  bool _isSelectedDate(TimeRecord record) {
    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return record.startTime.isBefore(dayStart.add(const Duration(days: 1))) &&
        record.endTime.isAfter(dayStart);
  }

  TimeRecord _clipToSelectedDate(TimeRecord record) {
    final dayStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    return record.copyWith(
      startTime: record.startTime.isAfter(dayStart)
          ? record.startTime
          : dayStart,
      endTime: record.endTime.isBefore(dayEnd) ? record.endTime : dayEnd,
    );
  }

  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = _TimelineViewMode.day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _viewMode == _TimelineViewMode.day
                      ? context.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '日',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _viewMode == _TimelineViewMode.day
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = _TimelineViewMode.week),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _viewMode == _TimelineViewMode.week
                      ? context.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '周',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _viewMode == _TimelineViewMode.week
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _renderedHourHeight = _hourHeight;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DateNavigator(
              date: _selectedDate,
              onPrev: () => _onDateChanged(-1),
              onNext: () => _onDateChanged(1),
            ),
            _buildViewToggle(),
            Expanded(
              child: BlocBuilder<RecordsBloc, RecordsState>(
                builder: (context, state) {
                  if (state is RecordsLoading || state is RecordsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is RecordsLoaded) {
                    if (_viewMode == _TimelineViewMode.week) {
                      return WeekView(
                        selectedDate: _selectedDate,
                        records: state.records,
                        onDayTap: (date) {
                          setState(() {
                            _selectedDate = date;
                            _viewMode = _TimelineViewMode.day;
                          });
                        },
                      );
                    }
                    return _buildTimeline(
                      state.records
                          .where(_isSelectedDate)
                          .map(_clipToSelectedDate)
                          .toList(),
                    );
                  }
                  return Center(
                    child: Text(
                      '暂无记录',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(List<TimeRecord> records) {
    final layouts = TimelineLayout.calculate(
      records,
      hourHeight: _hourHeight,
      minCardHeight: _minCardHeight,
    );
    final availableWidth = MediaQuery.of(context).size.width - 40 - _labelWidth;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _restoreDefaultScale,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              child: SizedBox(
                height: 24 * _hourHeight,
                child: Stack(
                  children: [
                    ...List.generate(25, (hour) => _buildHourRow(hour)),
                    ...layouts.map(
                      (layout) => Positioned(
                        top: layout.top,
                        left:
                            _labelWidth +
                            layout.column *
                                (availableWidth / layout.columnCount),
                        width: availableWidth / layout.columnCount - 4,
                        height: layout.height,
                        child: TimelineCard(record: layout.record),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showsScaleFeedback)
              Positioned(
                top: 12,
                right: 20,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '100%',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourRow(int hour) {
    return Positioned(
      top: hour * _hourHeight,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: TextStyle(
                fontSize: 11,
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(height: 0, color: context.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
