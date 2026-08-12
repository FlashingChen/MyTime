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
        createdAt: now,
      );
      final r2 = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        createdAt: now,
      );
      expect(r1, equals(r2));
    });

    test('equality includes createdAt', () {
      final now = DateTime(2026, 7, 9);
      final r1 = TimeRecord(
        id: '1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        createdAt: now,
      );
      final r2 = TimeRecord(
        id: '1',
        startTime: now,
        endTime: now.add(const Duration(hours: 1)),
        createdAt: now.add(const Duration(days: 1)),
      );
      expect(r1, isNot(equals(r2)));
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
      expect(updated.categoryId, 'work');
    });

    test('allows nullable categoryId for uncategorized records', () {
      final record = TimeRecord(
        id: '1',
        categoryId: null,
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      );
      expect(record.categoryId, isNull);
    });

    test('copyWith can set categoryId to null', () {
      final record = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      );
      final updated = record.copyWith(categoryId: null);
      expect(updated.categoryId, isNull);
    });

    test('copyWith preserves nullable fields when they are omitted', () {
      final record = TimeRecord(
        id: '1',
        categoryId: null,
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
        note: 'Keep this note',
      );

      final updated = record.copyWith(endTime: DateTime(2026, 7, 9, 10));

      expect(updated.categoryId, isNull);
      expect(updated.note, 'Keep this note');
    });

    test('copyWith can explicitly clear note', () {
      final record = TimeRecord(
        id: '1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
        note: 'Temporary note',
      );

      final updated = record.copyWith(note: null);

      expect(updated.note, isNull);
    });
  });
}
