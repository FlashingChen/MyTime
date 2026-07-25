import 'package:mytime/data/models/time_record.dart';

/// The period represented by the statistics screen.
enum StatsRange { day, week, month }

/// One labelled duration bucket in the trend chart.
class StatsTrendPoint {
  const StatsTrendPoint({
    required this.label,
    required this.duration,
    this.categoryDurations = const {},
  });

  final String label;
  final Duration duration;
  final Map<String, Duration> categoryDurations;
}

/// Pure, range-aware metrics consumed by the statistics widgets.
class StatsMetrics {
  const StatsMetrics({
    required this.range,
    required this.records,
    required this.total,
    required this.previousTotal,
    required this.average,
    required this.byCategory,
    required this.categoryRecordCounts,
    required this.trend,
  });

  final StatsRange range;

  /// Records clipped to the selected range, for consumers that need sessions.
  final List<TimeRecord> records;
  final Duration total;
  final Duration previousTotal;
  final Duration average;
  final Map<String, Duration> byCategory;
  final Map<String, int> categoryRecordCounts;
  final List<StatsTrendPoint> trend;

  static StatsMetrics forRange(
    List<TimeRecord> records,
    StatsRange range,
    DateTime now,
  ) {
    final period = _periodFor(range, now);
    final previous = _previousPeriodFor(range, period);
    final categoryDurations = <String, Duration>{};
    final categoryCounts = <String, int>{};
    final periodRecords = <TimeRecord>[];
    Duration total = Duration.zero;
    for (final record in records) {
      final duration = _overlap(record, period);
      if (duration == Duration.zero) continue;
      final startTime = record.startTime.isAfter(period.start)
          ? record.startTime
          : period.start;
      final endTime = record.endTime.isBefore(period.end)
          ? record.endTime
          : period.end;
      periodRecords.add(
        TimeRecord(
          id: record.id,
          categoryId: record.categoryId,
          startTime: startTime,
          endTime: endTime,
          note: record.note,
          createdAt: record.createdAt,
        ),
      );
      total += duration;
      final key = record.categoryId ?? 'uncategorized';
      categoryDurations[key] =
          (categoryDurations[key] ?? Duration.zero) + duration;
      categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
    }
    final previousTotal = records.fold<Duration>(
      Duration.zero,
      (sum, record) => sum + _overlap(record, previous),
    );
    final days = period.end.difference(period.start).inDays;
    return StatsMetrics(
      range: range,
      records: List.unmodifiable(periodRecords),
      total: total,
      previousTotal: previousTotal,
      average: days == 0
          ? Duration.zero
          : Duration(minutes: total.inMinutes ~/ days),
      byCategory: Map.unmodifiable(categoryDurations),
      categoryRecordCounts: Map.unmodifiable(categoryCounts),
      trend: List.unmodifiable(_trend(records, range, period)),
    );
  }

  static _DateRange _periodFor(StatsRange range, DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    switch (range) {
      case StatsRange.day:
        return _DateRange(day, day.add(const Duration(days: 1)));
      case StatsRange.week:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return _DateRange(start, start.add(const Duration(days: 7)));
      case StatsRange.month:
        return _DateRange(
          DateTime(now.year, now.month),
          DateTime(now.year, now.month + 1),
        );
    }
  }

  static _DateRange _previousPeriodFor(StatsRange range, _DateRange period) {
    if (range != StatsRange.month) {
      final duration = period.end.difference(period.start);
      return _DateRange(period.start.subtract(duration), period.start);
    }
    final previousMonthStart = DateTime(
      period.start.year,
      period.start.month - 1,
    );
    return _DateRange(previousMonthStart, period.start);
  }

  static Duration _overlap(TimeRecord record, _DateRange range) {
    final start = record.startTime.isAfter(range.start)
        ? record.startTime
        : range.start;
    final end = record.endTime.isBefore(range.end) ? record.endTime : range.end;
    return end.isAfter(start) ? end.difference(start) : Duration.zero;
  }

  static List<StatsTrendPoint> _trend(
    List<TimeRecord> records,
    StatsRange range,
    _DateRange period,
  ) {
    final count = switch (range) {
      StatsRange.day => 24,
      StatsRange.week => 7,
      StatsRange.month =>
        period.end.day == 1
            ? period.end.subtract(const Duration(days: 1)).day
            : period.end.day,
    };
    return List.generate(count, (index) {
      final start = switch (range) {
        StatsRange.day => period.start.add(Duration(hours: index)),
        _ => period.start.add(Duration(days: index)),
      };
      final end = range == StatsRange.day
          ? start.add(const Duration(hours: 1))
          : start.add(const Duration(days: 1));
      final slot = _DateRange(start, end);
      Duration total = Duration.zero;
      final categoryDurations = <String, Duration>{};
      for (final record in records) {
        final d = _overlap(record, slot);
        if (d == Duration.zero) continue;
        total += d;
        final key = record.categoryId ?? 'uncategorized';
        categoryDurations[key] = (categoryDurations[key] ?? Duration.zero) + d;
      }
      final label = switch (range) {
        StatsRange.day => index.toString().padLeft(2, '0'),
        StatsRange.week => const ['一', '二', '三', '四', '五', '六', '日'][index],
        StatsRange.month => '${index + 1}',
      };
      return StatsTrendPoint(
        label: label,
        duration: total,
        categoryDurations: categoryDurations,
      );
    });
  }
}

/// Formats a tracked duration for compact, human-readable statistics labels.
String formatStatsDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

class _DateRange {
  const _DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
