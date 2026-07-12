import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/record_repository.dart';

void main() {
  late Box<TimeRecord> box;
  late RecordRepository repo;

  setUp(() async {
    Hive.init('test_hive');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TimeRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    box = await Hive.openBox<TimeRecord>('test_records');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  test('add returns a record with generated id', () async {
    final record = TimeRecord(
      id: '',
      categoryId: 'work',
      startTime: DateTime(2026, 7, 9, 8, 30),
      endTime: DateTime(2026, 7, 9, 9, 50),
    );
    final result = await repo.add(record);
    expect(result.id, isNotEmpty);
    expect(result.categoryId, 'work');
  });

  test(
    'add preserves a supplied id so retries do not duplicate records',
    () async {
      final record = TimeRecord(
        id: 'stable-id',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 30),
        endTime: DateTime(2026, 7, 9, 9, 50),
      );

      await repo.add(record);
      await repo.add(record);

      expect(repo.getAll(), hasLength(1));
      expect(repo.getAll().single.id, 'stable-id');
    },
  );

  test('add rejects a record whose end is not after its start', () async {
    final record = TimeRecord(
      id: '',
      categoryId: 'work',
      startTime: DateTime(2026, 7, 9, 9),
      endTime: DateTime(2026, 7, 9, 9),
    );

    expect(repo.add(record), throwsArgumentError);
  });

  test('changes emits after a record is saved', () async {
    final change = repo.changes.first;

    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8),
        endTime: DateTime(2026, 7, 9, 9),
      ),
    );

    await expectLater(change, completes);
  });

  test('getAll returns records sorted by startTime desc', () async {
    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      ),
    );
    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 9, 10, 0),
        endTime: DateTime(2026, 7, 9, 11, 0),
      ),
    );
    final all = repo.getAll();
    expect(all.length, 2);
    expect(all[0].startTime.hour, 10);
  });

  test('getByDate filters records for a specific date', () async {
    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      ),
    );
    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 10, 8, 0),
        endTime: DateTime(2026, 7, 10, 9, 0),
      ),
    );
    final day9 = repo.getByDate(DateTime(2026, 7, 9));
    expect(day9.length, 1);
    expect(day9[0].categoryId, 'work');
  });

  test(
    'getByDate includes records that cross into the selected date',
    () async {
      await repo.add(
        TimeRecord(
          id: '',
          categoryId: 'work',
          startTime: DateTime(2026, 7, 9, 23),
          endTime: DateTime(2026, 7, 10, 1),
        ),
      );

      expect(repo.getByDate(DateTime(2026, 7, 9)), hasLength(1));
      expect(repo.getByDate(DateTime(2026, 7, 10)), hasLength(1));
    },
  );

  test('clearCategory sets categoryId to null for matching records', () async {
    final r1 = await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      ),
    );
    await repo.add(
      TimeRecord(
        id: '',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 9, 10, 0),
        endTime: DateTime(2026, 7, 9, 11, 0),
      ),
    );
    await repo.clearCategory('work');
    final updated = repo.getAll().firstWhere((r) => r.id == r1.id);
    expect(updated.categoryId, isNull);
    final other = repo.getAll().firstWhere((r) => r.categoryId == 'read');
    expect(other.categoryId, 'read');
  });
}
