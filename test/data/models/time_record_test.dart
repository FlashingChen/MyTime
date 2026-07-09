import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';

void main() {
  group('TimeRecord', () {
    test('creates with required fields', () {
      final record = TimeRecord(
        id: 'test-id',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 30),
        endTime: DateTime(2026, 7, 9, 9, 50),
      );
      expect(record.id, 'test-id');
      expect(record.categoryId, 'work');
      expect(record.note, isNull);
    });

    test('duration returns correct difference', () {
      final record = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 30),
        endTime: DateTime(2026, 7, 9, 9, 50),
      );
      expect(record.duration.inMinutes, 80);
    });

    test('equality works via Equatable', () {
      final now = DateTime(2026, 7, 9);
      final r1 = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
      );
      final r2 = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
      );
      expect(r1, equals(r2));
    });

    test('copyWith creates new instance with updated fields', () {
      final record = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      );
      final updated = record.copyWith(note: 'Updated note');
      expect(updated.id, '1');
      expect(updated.note, 'Updated note');
      expect(updated.startTime, record.startTime);
    });
  });
}
