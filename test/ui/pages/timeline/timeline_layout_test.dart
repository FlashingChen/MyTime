import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/timeline_layout.dart';

void main() {
  TimeRecord record(
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) {
    return TimeRecord(
      id: '$startHour:$startMinute-$endHour:$endMinute',
      categoryId: 'work',
      startTime: DateTime(2026, 7, 10, startHour, startMinute),
      endTime: DateTime(2026, 7, 10, endHour, endMinute),
    );
  }

  test('visually adjacent short records use two columns', () {
    final layouts = TimelineLayout.calculate(
      [record(9, 0, 9, 10), record(9, 15, 9, 45)],
      hourHeight: 60,
      minCardHeight: 24,
    );

    expect(layouts.map((item) => item.column), [0, 1]);
    expect(layouts.map((item) => item.columnCount), [2, 2]);
  });

  test('record after an overlap group returns to one column', () {
    final layouts = TimelineLayout.calculate(
      [record(9, 0, 10, 0), record(9, 30, 10, 30), record(11, 0, 12, 0)],
      hourHeight: 60,
      minCardHeight: 24,
    );

    expect(layouts[2].columnCount, 1);
  });

  test('record ending exactly at midnight spans the full hour', () {
    final layouts = TimelineLayout.calculate(
      [
        TimeRecord(
          id: 'midnight',
          startTime: DateTime(2026, 7, 10, 23, 0),
          endTime: DateTime(2026, 7, 11, 0, 0),
        ),
      ],
      hourHeight: 60,
      minCardHeight: 24,
    );

    expect(layouts.single.top, 23 * 60.0);
    expect(layouts.single.height, 60.0);
  });

  test('clipped cross-midnight record spans to the end of the day', () {
    // Mirrors _clipToSelectedDate output: the endTime becomes next-day 00:00.
    final layouts = TimelineLayout.calculate(
      [
        TimeRecord(
          id: 'overnight',
          startTime: DateTime(2026, 7, 10, 22, 30),
          endTime: DateTime(2026, 7, 11, 0, 0),
        ),
      ],
      hourHeight: 60,
      minCardHeight: 24,
    );

    expect(layouts.single.top, 22.5 * 60.0);
    expect(layouts.single.height, 90.0);
  });

  test('positions account for seconds', () {
    final layouts = TimelineLayout.calculate(
      [
        TimeRecord(
          id: 'seconds',
          startTime: DateTime(2026, 7, 10, 10, 30, 45),
          endTime: DateTime(2026, 7, 10, 11, 30),
        ),
      ],
      hourHeight: 60,
      minCardHeight: 24,
    );

    expect(layouts.single.top, closeTo(630.75, 0.001));
  });
}
