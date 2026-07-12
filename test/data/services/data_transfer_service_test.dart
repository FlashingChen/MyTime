import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/services/data_transfer_service.dart';

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
