import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

void main() {
  test('clips records to the selected statistics period', () {
    final metrics = StatsMetrics.forRange(
      [
        TimeRecord(
          id: 'overnight',
          categoryId: 'work',
          startTime: DateTime(2026, 7, 9, 23),
          endTime: DateTime(2026, 7, 10, 1),
        ),
      ],
      StatsRange.day,
      DateTime(2026, 7, 10, 12),
    );

    expect(metrics.records, hasLength(1));
    expect(metrics.records.single.duration, const Duration(hours: 1));
    expect(metrics.total, const Duration(hours: 1));
  });

  test('formats chart durations without decimal hours', () {
    expect(
      formatStatsDuration(const Duration(hours: 4, minutes: 30)),
      '4h 30m',
    );
    expect(formatStatsDuration(const Duration(minutes: 45)), '45m');
  });
}
