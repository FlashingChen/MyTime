import 'package:mytime/data/models/time_record.dart';

/// The calculated position and overlap column for a timeline record card.
class TimelineCardLayout {
  const TimelineCardLayout({
    required this.record,
    required this.top,
    required this.height,
    required this.column,
    required this.columnCount,
  });

  final TimeRecord record;
  final double top;
  final double height;
  final int column;
  final int columnCount;
}

/// Calculates vertical card positions and visual-overlap columns for a day.
class TimelineLayout {
  const TimelineLayout._();

  /// Lays out [records] using pixels per hour and a minimum visual card height.
  static List<TimelineCardLayout> calculate(
    List<TimeRecord> records, {
    required double hourHeight,
    required double minCardHeight,
  }) {
    final intervals =
        records
            .map(
              (record) => _VisualInterval(
                record: record,
                top: _minutesSinceMidnight(record.startTime) / 60 * hourHeight,
                actualEnd:
                    _minutesSinceMidnight(record.endTime) / 60 * hourHeight,
                minCardHeight: minCardHeight,
              ),
            )
            .toList()
          ..sort((a, b) {
            final startComparison = a.top.compareTo(b.top);
            if (startComparison != 0) return startComparison;
            return a.visualEnd.compareTo(b.visualEnd);
          });

    final layouts = <TimelineCardLayout>[];
    var groupStart = 0;
    while (groupStart < intervals.length) {
      var groupEnd = groupStart + 1;
      var maximumVisualEnd = intervals[groupStart].visualEnd;
      while (groupEnd < intervals.length &&
          intervals[groupEnd].top < maximumVisualEnd) {
        maximumVisualEnd = maximumVisualEnd < intervals[groupEnd].visualEnd
            ? intervals[groupEnd].visualEnd
            : maximumVisualEnd;
        groupEnd++;
      }

      layouts.addAll(_layoutGroup(intervals.sublist(groupStart, groupEnd)));
      groupStart = groupEnd;
    }

    return layouts;
  }

  static List<TimelineCardLayout> _layoutGroup(List<_VisualInterval> group) {
    final columnEnds = <double>[];
    final assignments = <int>[];

    for (final interval in group) {
      var column = columnEnds.indexWhere((end) => end <= interval.top);
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(interval.visualEnd);
      } else {
        columnEnds[column] = interval.visualEnd;
      }
      assignments.add(column);
    }

    return List.generate(
      group.length,
      (index) => TimelineCardLayout(
        record: group[index].record,
        top: group[index].top,
        height: group[index].height,
        column: assignments[index],
        columnCount: columnEnds.length,
      ),
    );
  }

  static int _minutesSinceMidnight(DateTime value) =>
      value.hour * 60 + value.minute;
}

class _VisualInterval {
  _VisualInterval({
    required this.record,
    required this.top,
    required this.actualEnd,
    required this.minCardHeight,
  });

  final TimeRecord record;
  final double top;
  final double actualEnd;
  final double minCardHeight;

  double get visualEnd =>
      actualEnd < top + minCardHeight ? top + minCardHeight : actualEnd;

  double get height => visualEnd - top;
}
