import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/services/data_transfer_service.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';

void main() {
  late _MemoryCategoryStore categoryStore;
  late _MemoryRecordStore recordStore;
  late DataTransferService service;

  setUp(() {
    categoryStore = _MemoryCategoryStore();
    recordStore = _MemoryRecordStore();
    service = DataTransferService(
      RecordRepository.withStore(recordStore),
      CategoryRepository.withStore(categoryStore),
    );
  });

  test('replaces data only after a complete valid backup is parsed', () async {
    await service.importJson('''
      {"version":1,"categories":[{"id":"work","name":"工作","color":"#123456"}],"records":[{"id":"r1","categoryId":"work","startTime":"2026-07-10T09:00:00.000","endTime":"2026-07-10T10:00:00.000","note":null}]}
    ''');

    expect(categoryStore.values.single.name, '工作');
    expect(recordStore.values.single.id, 'r1');
  });

  test('leaves existing data untouched when backup validation fails', () async {
    await categoryStore.put(
      'old',
      Category(id: 'old', name: '旧分类', color: '#111111'),
    );

    await expectLater(
      service.importJson('{"version":1,"categories":[],"records":[{}]}'),
      throwsFormatException,
    );

    expect(categoryStore.values.single.id, 'old');
  });

  test('rejects a valid-shaped backup that removes every category', () async {
    await categoryStore.put(
      'old',
      Category(id: 'old', name: '旧分类', color: '#111111'),
    );

    await expectLater(
      service.importJson('{"version":1,"categories":[],"records":[]}'),
      throwsFormatException,
    );

    expect(categoryStore.values.single.id, 'old');
  });

  test('restores prior data when record persistence fails', () async {
    await categoryStore.put(
      'old',
      Category(id: 'old', name: '旧分类', color: '#111111'),
    );
    await recordStore.put(
      'old-record',
      TimeRecord(
        id: 'old-record',
        categoryId: 'old',
        startTime: DateTime(2026, 7, 9, 9),
        endTime: DateTime(2026, 7, 9, 10),
      ),
    );
    recordStore.failNextPutAll = true;

    await expectLater(
      service.importJson('''
        {"version":1,"categories":[{"id":"new","name":"新分类","color":"#222222"}],"records":[{"id":"new-record","categoryId":"new","startTime":"2026-07-10T09:00:00.000","endTime":"2026-07-10T10:00:00.000","note":null}]}
      '''),
      throwsStateError,
    );

    expect(categoryStore.values.single.id, 'old');
    expect(recordStore.values.single.id, 'old-record');
  });

  test('marks one local mutation after a complete import succeeds', () async {
    final marker = _FakeMutationTracker();
    service = DataTransferService(
      RecordRepository.withStore(recordStore),
      CategoryRepository.withStore(categoryStore),
      mutationMarker: marker,
    );

    await service.importJson('''
      {"version":1,"categories":[{"id":"work","name":"工作","color":"#123456"}],"records":[{"id":"r1","categoryId":"work","startTime":"2026-07-10T09:00:00.000","endTime":"2026-07-10T10:00:00.000","note":null}]}
    ''');

    expect(marker.calls, 1);
  });

  test('does not mark a failed import as a local mutation', () async {
    final marker = _FakeMutationTracker();
    service = DataTransferService(
      RecordRepository.withStore(recordStore),
      CategoryRepository.withStore(categoryStore),
      mutationMarker: marker,
    );

    await expectLater(
      service.importJson('{"version":1,"categories":[],"records":[{}]}'),
      throwsFormatException,
    );

    expect(marker.calls, 0);
  });

  test(
    'refreshes the snapshot after import with a non-entity marker',
    () async {
      final marker = _FakeMutationTracker();
      var refreshes = 0;
      service = DataTransferService(
        RecordRepository.withStore(recordStore),
        CategoryRepository.withStore(categoryStore),
        mutationMarker: marker,
        refreshSnapshot: () async => refreshes++,
      );

      await service.importJson('''
      {"version":1,"categories":[{"id":"work","name":"工作","color":"#123456"}],"records":[]}
    ''');

      expect(marker.calls, 1);
      expect(refreshes, 1);
    },
  );

  test(
    'refreshes the snapshot after import without a mutation marker',
    () async {
      var refreshes = 0;
      service = DataTransferService(
        RecordRepository.withStore(recordStore),
        CategoryRepository.withStore(categoryStore),
        refreshSnapshot: () async => refreshes++,
      );

      await service.importJson('''
      {"version":1,"categories":[{"id":"work","name":"工作","color":"#123456"}],"records":[]}
    ''');

      expect(refreshes, 1);
    },
  );

  test(
    'schedules an imported sync only after its snapshot is published',
    () async {
      final events = <String>[];
      final marker = SyncMutationTracker(
        revision: _MemoryRevisionStore(DateTime.utc(2026, 7, 1)),
        metadata: _MemoryMetadataStore(const SyncMetadata()),
        scheduler: _EventScheduler(events),
        clock: () => DateTime.utc(2026, 7, 2),
      );
      service = DataTransferService(
        RecordRepository.withStore(recordStore),
        CategoryRepository.withStore(categoryStore),
        mutationMarker: marker,
        refreshSnapshot: () async => events.add('snapshot'),
      );

      await service.importJson('''
      {"version":1,"categories":[{"id":"work","name":"工作","color":"#123456"}],"records":[]}
    ''');

      expect(events, ['snapshot', 'schedule']);
    },
  );

  test(
    'restores captured snapshot when publication fails after writing',
    () async {
      await categoryStore.put(
        'old',
        const Category(id: 'old', name: '旧分类', color: '#111111'),
      );
      await recordStore.put(
        'old-record',
        TimeRecord(
          id: 'old-record',
          categoryId: 'old',
          startTime: DateTime.utc(2026, 7, 9, 9),
          endTime: DateTime.utc(2026, 7, 9, 10),
        ),
      );
      final revision = _MemoryRevisionStore(DateTime.utc(2026, 7, 1));
      final oldMetadata = SyncMetadata(
        records: {
          'old-record': SyncEntityMetadata(
            kind: SyncEntityKind.record,
            id: 'old-record',
            updatedAt: DateTime.utc(2026, 6, 30),
          ),
        },
        categories: {
          'removed-category': SyncEntityMetadata(
            kind: SyncEntityKind.category,
            id: 'removed-category',
            deletedAt: DateTime.utc(2026, 6, 29),
          ),
        },
      );
      final metadata = _MemoryMetadataStore(oldMetadata);
      var serializedSnapshot = 'old snapshot';
      var publicationAttempts = 0;
      final scheduler = _CountingScheduler();
      final marker = SyncMutationTracker(
        revision: revision,
        metadata: metadata,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 7, 2),
      );
      service = DataTransferService(
        RecordRepository.withStore(recordStore),
        CategoryRepository.withStore(categoryStore),
        mutationMarker: marker,
        refreshSnapshot: () async {
          publicationAttempts++;
          serializedSnapshot = 'new snapshot';
          throw StateError('snapshot publication failed');
        },
        captureSnapshot: () async => serializedSnapshot,
        restoreSnapshot: (snapshot) async => serializedSnapshot = snapshot!,
      );

      await expectLater(
        service.importJson('''
          {"version":1,"categories":[{"id":"new","name":"新分类","color":"#222222"}],"records":[{"id":"new-record","categoryId":"new","startTime":"2026-07-10T09:00:00.000Z","endTime":"2026-07-10T10:00:00.000Z","note":null}]}
        '''),
        throwsStateError,
      );

      expect(publicationAttempts, 1);
      expect(scheduler.calls, 0);
      expect(categoryStore.values.single.id, 'old');
      expect(recordStore.values.single.id, 'old-record');
      expect(await revision.readUpdatedAt(), DateTime.utc(2026, 7, 1));
      expect(await metadata.read(), oldMetadata);
      expect(serializedSnapshot, 'old snapshot');
    },
  );
}

class _FakeMutationTracker implements SyncMutationMarker {
  int calls = 0;

  @override
  Future<void> markLocalChanged() async {
    calls++;
  }
}

class _MemoryRevisionStore implements SyncRevisionStore {
  _MemoryRevisionStore(this.value);

  DateTime value;

  @override
  Future<DateTime> readUpdatedAt() async => value;

  @override
  Future<void> writeUpdatedAt(DateTime updatedAt) async => value = updatedAt;
}

class _MemoryMetadataStore implements SyncMetadataStore {
  _MemoryMetadataStore(this.value);

  SyncMetadata value;

  @override
  Future<void> markChanged(
    SyncEntityKind kind,
    String id,
    DateTime changedAt,
  ) async {}

  @override
  Future<void> markDeleted(
    SyncEntityKind kind,
    String id,
    DateTime deletedAt,
  ) async {}

  @override
  Future<SyncMetadata> read() async => value;

  @override
  Future<void> write(SyncMetadata metadata) async => value = metadata;
}

class _EventScheduler implements SyncScheduler {
  _EventScheduler(this.events);

  final List<String> events;

  @override
  Future<void> schedule() async => events.add('schedule');
}

class _CountingScheduler implements SyncScheduler {
  int calls = 0;

  @override
  Future<void> schedule() async => calls++;
}

class _MemoryRecordStore implements RecordDataStore {
  final data = <String, TimeRecord>{};
  bool failNextPutAll = false;
  @override
  Iterable<TimeRecord> get values => data.values;
  @override
  Stream<void> get changes => const Stream<void>.empty();
  @override
  Future<void> clear() async => data.clear();
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<void> put(String key, TimeRecord value) async => data[key] = value;
  @override
  Future<void> putAll(Map<String, TimeRecord> values) async {
    if (failNextPutAll) {
      failNextPutAll = false;
      throw StateError('write failed');
    }
    data.addAll(values);
  }
}

class _MemoryCategoryStore implements CategoryDataStore {
  final data = <String, Category>{};
  @override
  Iterable<Category> get values => data.values;
  @override
  bool get isEmpty => data.isEmpty;
  @override
  Future<void> clear() async => data.clear();
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Category? get(String key) => data[key];
  @override
  Future<void> put(String key, Category value) async => data[key] = value;
  @override
  Future<void> putAll(Map<String, Category> values) async =>
      data.addAll(values);
}
