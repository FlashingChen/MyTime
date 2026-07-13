import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/sync/revision_tracking_repositories.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';

void main() {
  final category = const Category(id: 'work', name: '工作', color: '#123456');
  final updatedCategory = const Category(
    id: 'work',
    name: '深度工作',
    color: '#654321',
  );
  TimeRecord recordFor(String categoryId) => TimeRecord(
    id: 'record',
    categoryId: categoryId,
    startTime: DateTime.utc(2026, 7, 12, 9),
    endTime: DateTime.utc(2026, 7, 12, 10),
  );

  test(
    'marks every successful record write through the existing port',
    () async {
      final delegate = _FakeRecordsRepository();
      final marker = _FakeMutationTracker();
      final repository = RevisionTrackingRecordsRepository(
        delegate: delegate,
        marker: marker,
      );
      final record = recordFor(category.id);

      await repository.add(record);
      await repository.update(record.copyWith(note: '已更新'));
      await repository.reassignCategory(category.id, 'personal');
      await repository.clearCategory('personal');
      await repository.delete(record.id);

      expect(marker.calls, 5);
      expect(delegate.getAll(), isEmpty);
    },
  );

  test('does not mark a failed record write as a local mutation', () async {
    final delegate = _FakeRecordsRepository()..failNextWrite = true;
    final marker = _FakeMutationTracker();
    final repository = RevisionTrackingRecordsRepository(
      delegate: delegate,
      marker: marker,
    );

    await expectLater(repository.add(recordFor(category.id)), throwsStateError);

    expect(marker.calls, 0);
  });

  test(
    'marks every successful category write through the existing port',
    () async {
      final delegate = _FakeCategoriesRepository();
      final marker = _FakeMutationTracker();
      final repository = RevisionTrackingCategoriesRepository(
        delegate: delegate,
        marker: marker,
      );

      await repository.add(category);
      await repository.update(updatedCategory);
      await repository.delete(category.id);

      expect(marker.calls, 3);
      expect(delegate.getAll(), isEmpty);
    },
  );

  test('does not mark a failed category write as a local mutation', () async {
    final delegate = _FakeCategoriesRepository()..failNextWrite = true;
    final marker = _FakeMutationTracker();
    final repository = RevisionTrackingCategoriesRepository(
      delegate: delegate,
      marker: marker,
    );

    await expectLater(repository.add(category), throwsStateError);

    expect(marker.calls, 0);
  });
}

class _FakeMutationTracker implements SyncMutationMarker {
  int calls = 0;

  @override
  Future<void> markLocalChanged() async {
    calls++;
  }
}

class _FakeRecordsRepository implements RecordsRepository {
  final Map<String, TimeRecord> _records = {};
  bool failNextWrite = false;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    _throwIfRequested();
    _records[record.id] = record;
    return record;
  }

  @override
  Future<void> clearCategory(String categoryId) async {
    _throwIfRequested();
    for (final entry in _records.entries.toList()) {
      if (entry.value.categoryId == categoryId) {
        _records[entry.key] = entry.value.copyWith(categoryId: null);
      }
    }
  }

  @override
  Future<void> delete(String id) async {
    _throwIfRequested();
    _records.remove(id);
  }

  @override
  List<TimeRecord> getAll() => _records.values.toList();

  @override
  List<TimeRecord> getByDate(DateTime date) => getAll();

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => getAll();

  @override
  Future<void> reassignCategory(
    String fromCategoryId,
    String toCategoryId,
  ) async {
    _throwIfRequested();
    for (final entry in _records.entries.toList()) {
      if (entry.value.categoryId == fromCategoryId) {
        _records[entry.key] = entry.value.copyWith(categoryId: toCategoryId);
      }
    }
  }

  @override
  Future<void> update(TimeRecord record) async {
    _throwIfRequested();
    _records[record.id] = record;
  }

  void _throwIfRequested() {
    if (!failNextWrite) return;
    failNextWrite = false;
    throw StateError('simulated write failure');
  }
}

class _FakeCategoriesRepository implements CategoriesRepository {
  final Map<String, Category> _categories = {};
  bool failNextWrite = false;

  @override
  Future<Category> add(Category category) async {
    _throwIfRequested();
    _categories[category.id] = category;
    return category;
  }

  @override
  Future<void> delete(String id) async {
    _throwIfRequested();
    _categories.remove(id);
  }

  @override
  List<Category> getAll() => _categories.values.toList();

  @override
  Category? getById(String id) => _categories[id];

  @override
  Future<void> update(Category category) async {
    _throwIfRequested();
    _categories[category.id] = category;
  }

  void _throwIfRequested() {
    if (!failNextWrite) return;
    failNextWrite = false;
    throw StateError('simulated write failure');
  }
}
