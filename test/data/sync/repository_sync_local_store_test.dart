import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/sync/revision_tracking_repositories.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';

void main() {
  final oldCategory = const Category(id: 'old', name: '旧分类', color: '#123456');
  final newCategory = const Category(id: 'new', name: '新分类', color: '#654321');

  TimeRecord recordFor(String categoryId, {String id = 'record'}) => TimeRecord(
    id: id,
    categoryId: categoryId,
    startTime: DateTime.utc(2026, 7, 12, 9),
    endTime: DateTime.utc(2026, 7, 12, 10),
    createdAt: DateTime.utc(2026, 7, 12, 9),
  );

  test(
    'reads a local snapshot from repositories and its stored revision',
    () async {
      final records = _FakeRecordsRepository([recordFor(oldCategory.id)]);
      final categories = _FakeCategoriesRepository([oldCategory]);
      final revision = _FakeRevisionStore(DateTime.utc(2026, 7, 12, 9));
      final store = RepositorySyncLocalStore(
        records: records,
        categories: categories,
        revision: revision,
      );

      final snapshot = await store.read();

      expect(snapshot.updatedAt, DateTime.utc(2026, 7, 12, 9));
      expect(snapshot.records, [recordFor(oldCategory.id)]);
      expect(snapshot.categories, [oldCategory]);
    },
  );

  test(
    'replaces the complete local dataset before storing remote revision',
    () async {
      final records = _FakeRecordsRepository([recordFor(oldCategory.id)]);
      final categories = _FakeCategoriesRepository([oldCategory]);
      final revision = _FakeRevisionStore(DateTime.utc(2026, 7, 12, 9));
      final store = RepositorySyncLocalStore(
        records: records,
        categories: categories,
        revision: revision,
      );
      final remote = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 12, 10),
        categories: [newCategory],
        records: [recordFor(newCategory.id)],
      );

      await store.replace(remote);

      expect(records.getAll(), [recordFor(newCategory.id)]);
      expect(categories.getAll(), [newCategory]);
      expect(revision.value, DateTime.utc(2026, 7, 12, 10));
    },
  );

  test('does not replace when a local revision has advanced', () async {
    final records = _FakeRecordsRepository([recordFor(oldCategory.id)]);
    final categories = _FakeCategoriesRepository([oldCategory]);
    final revision = _FakeRevisionStore(DateTime.utc(2026, 7, 12, 11));
    final store = RepositorySyncLocalStore(
      records: records,
      categories: categories,
      revision: revision,
    );
    final remote = SyncSnapshot(
      updatedAt: DateTime.utc(2026, 7, 12, 12),
      categories: [newCategory],
      records: [recordFor(newCategory.id)],
    );

    final replaced = await store.replaceIfCurrent(
      DateTime.utc(2026, 7, 12, 10),
      remote,
    );

    expect(replaced, isFalse);
    expect(records.getAll(), [recordFor(oldCategory.id)]);
    expect(categories.getAll(), [oldCategory]);
    expect(revision.value, DateTime.utc(2026, 7, 12, 11));
  });

  test(
    'restores local data and revision if applying a snapshot fails',
    () async {
      final records = _FakeRecordsRepository([recordFor(oldCategory.id)])
        ..failNextUpdate = true;
      final categories = _FakeCategoriesRepository([oldCategory]);
      final initialRevision = DateTime.utc(2026, 7, 12, 9);
      final revision = _FakeRevisionStore(initialRevision);
      final store = RepositorySyncLocalStore(
        records: records,
        categories: categories,
        revision: revision,
      );
      final remote = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 12, 10),
        categories: [newCategory],
        records: [recordFor(newCategory.id)],
      );

      await expectLater(store.replace(remote), throwsStateError);

      expect(records.getAll(), [recordFor(oldCategory.id)]);
      expect(categories.getAll(), [oldCategory]);
      expect(revision.value, initialRevision);
    },
  );

  test(
    'applies a remote snapshot through raw repositories without marking it local',
    () async {
      final rawRecords = _FakeRecordsRepository([recordFor(oldCategory.id)]);
      final rawCategories = _FakeCategoriesRepository([oldCategory]);
      final revision = _FakeRevisionStore(DateTime.utc(2026, 7, 12, 9));
      final marker = _FakeMutationTracker();
      final appRecords = RevisionTrackingRecordsRepository(
        delegate: rawRecords,
        marker: marker,
      );
      final appCategories = RevisionTrackingCategoriesRepository(
        delegate: rawCategories,
        marker: marker,
      );
      final store = RepositorySyncLocalStore(
        records: rawRecords,
        categories: rawCategories,
        revision: revision,
      );
      final remote = SyncSnapshot(
        updatedAt: DateTime.utc(2026, 7, 12, 10),
        categories: [newCategory],
        records: [recordFor(newCategory.id)],
      );

      await store.replace(remote);

      expect(marker.calls, 0);
      expect(revision.value, remote.updatedAt);

      await appCategories.update(
        const Category(id: 'new', name: '已在本地修改', color: '#654321'),
      );
      await appRecords.update(recordFor(newCategory.id).copyWith(note: '本地修改'));

      expect(marker.calls, 2);
    },
  );
}

class _FakeRevisionStore implements SyncRevisionStore {
  _FakeRevisionStore(this.value);

  DateTime value;

  @override
  Future<DateTime> readUpdatedAt() async => value;

  @override
  Future<void> writeUpdatedAt(DateTime updatedAt) async {
    value = updatedAt;
  }
}

class _FakeMutationTracker implements SyncMutationMarker {
  int calls = 0;

  @override
  Future<void> markLocalChanged() async {
    calls++;
  }
}

class _FakeRecordsRepository implements RecordsRepository {
  _FakeRecordsRepository(Iterable<TimeRecord> initial)
    : _records = {for (final record in initial) record.id: record};

  final Map<String, TimeRecord> _records;
  bool failNextUpdate = false;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    _records[record.id] = record;
    return record;
  }

  @override
  Future<void> clearCategory(String categoryId) async {
    for (final entry in _records.entries.toList()) {
      if (entry.value.categoryId == categoryId) {
        _records[entry.key] = entry.value.copyWith(categoryId: null);
      }
    }
  }

  @override
  Future<void> delete(String id) async {
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
    for (final entry in _records.entries.toList()) {
      if (entry.value.categoryId == fromCategoryId) {
        _records[entry.key] = entry.value.copyWith(categoryId: toCategoryId);
      }
    }
  }

  @override
  Future<void> update(TimeRecord record) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('simulated record write failure');
    }
    _records[record.id] = record;
  }
}

class _FakeCategoriesRepository implements CategoriesRepository {
  _FakeCategoriesRepository(Iterable<Category> initial)
    : _categories = {for (final category in initial) category.id: category};

  final Map<String, Category> _categories;

  @override
  Future<Category> add(Category category) async {
    _categories[category.id] = category;
    return category;
  }

  @override
  Future<void> delete(String id) async {
    _categories.remove(id);
  }

  @override
  List<Category> getAll() => _categories.values.toList();

  @override
  Category? getById(String id) => _categories[id];

  @override
  Future<void> update(Category category) async {
    _categories[category.id] = category;
  }
}
