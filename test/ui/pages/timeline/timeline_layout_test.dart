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
}
