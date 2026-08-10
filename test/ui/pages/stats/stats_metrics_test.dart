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

  test('day/week/month produce different totals with multi-day records', () {
    final records = [
      TimeRecord(
        id: 'today_morning',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 10, 8),
        endTime: DateTime(2026, 7, 10, 8, 40),
      ),
      TimeRecord(
        id: 'yesterday',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 10),
        endTime: DateTime(2026, 7, 9, 12),
      ),
      TimeRecord(
        id: 'earlier_this_week',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 7, 14),
        endTime: DateTime(2026, 7, 7, 15, 30),
      ),
      TimeRecord(
        id: 'last_month',
        categoryId: 'sport',
        startTime: DateTime(2026, 6, 15, 9),
        endTime: DateTime(2026, 6, 15, 10),
      ),
    ];

    final now = DateTime(2026, 7, 10, 16);

    final dayMetrics = StatsMetrics.forRange(records, StatsRange.day, now);
    final weekMetrics = StatsMetrics.forRange(records, StatsRange.week, now);
    final monthMetrics = StatsMetrics.forRange(records, StatsRange.month, now);

    expect(
      dayMetrics.total,
      const Duration(minutes: 40),
      reason: 'Today should only include the 40min reading session',
    );

    expect(
      weekMetrics.total,
      const Duration(hours: 4, minutes: 10),
      reason:
          'This week (Mon 6 to Sun 12 Jul) should include 3 sessions '
          '(40min + 2h + 1h30min = 4h10min)',
    );

    expect(
      monthMetrics.total,
      const Duration(hours: 4, minutes: 10),
      reason:
          'This month (Jul) should include the same 3 sessions, '
          'since the June record is excluded',
    );
  });

  test('_periodFor day range is exactly 24 hours starting at midnight', () {
    final now = DateTime(2026, 7, 10, 15, 30);
    final day = DateTime(now.year, now.month, now.day);

    final metrics = StatsMetrics.forRange(
      [
        TimeRecord(
          id: 'r1',
          categoryId: 'read',
          startTime: day.subtract(const Duration(minutes: 5)),
          endTime: day.add(const Duration(hours: 1)),
        ),
      ],
      StatsRange.day,
      now,
    );

    expect(
      metrics.total,
      const Duration(hours: 1),
      reason:
          'Should clip from midnight, so 5min before midnight is '
          'excluded and only 1 hour after midnight counts',
    );
  });

  test('month compares against the preceding calendar month', () {
    final metrics = StatsMetrics.forRange(
      [
        TimeRecord(
          id: 'february',
          categoryId: 'work',
          startTime: DateTime(2026, 2, 15, 9),
          endTime: DateTime(2026, 2, 15, 10),
        ),
      ],
      StatsRange.month,
      DateTime(2026, 3, 15),
    );

    expect(metrics.previousTotal, const Duration(hours: 1));
  });

  test('trend points include per-category durations', () {
    final records = [
      TimeRecord(
        id: 'r1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 10, 9),
        endTime: DateTime(2026, 7, 10, 11),
      ),
      TimeRecord(
        id: 'r2',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 10, 14),
        endTime: DateTime(2026, 7, 10, 15, 30),
      ),
    ];
    final metrics = StatsMetrics.forRange(
      records,
      StatsRange.day,
      DateTime(2026, 7, 10, 16),
    );

    expect(metrics.trend, hasLength(24));
    // hour 9 (9:00-10:00) should have 1h of work
    expect(
      metrics.trend[9].categoryDurations['work'],
      const Duration(hours: 1),
    );
    // hour 10 (10:00-11:00) should have 1h of work
    expect(
      metrics.trend[10].categoryDurations['work'],
      const Duration(hours: 1),
    );
    // hour 14 (14:00-15:00) should have 1h of read
    expect(
      metrics.trend[14].categoryDurations['read'],
      const Duration(hours: 1),
    );
    // hour 14 should have no work
    expect(metrics.trend[14].categoryDurations['work'], isNull);
  });

  test('day range honors an explicit anchor date', () {
    final now = DateTime(2026, 7, 10, 12);
    final yesterday = DateTime(2026, 7, 9);
    final records = [
      TimeRecord(
        id: 'today',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 10, 9),
        endTime: DateTime(2026, 7, 10, 10),
      ),
      TimeRecord(
        id: 'yesterday',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 9, 20),
        endTime: DateTime(2026, 7, 9, 22),
      ),
    ];

    final metrics = StatsMetrics.forRange(
      records,
      StatsRange.day,
      now,
      anchorDate: yesterday,
    );

    expect(metrics.total, const Duration(hours: 2));
    expect(metrics.records, hasLength(1));
    expect(metrics.records.single.id, 'yesterday');
    expect(metrics.anchorDate, yesterday);
    expect(metrics.isToday, isFalse);
    expect(
      metrics.previousTotal,
      Duration.zero,
      reason: 'The day before the anchor has no records',
    );

    final todayMetrics = StatsMetrics.forRange(records, StatsRange.day, now);
    expect(todayMetrics.total, const Duration(hours: 1));
    expect(todayMetrics.records.single.id, 'today');
    expect(todayMetrics.isToday, isTrue);
  });
}
