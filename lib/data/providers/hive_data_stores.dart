import 'package:hive_ce/hive.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';

abstract interface class RecordDataStore {
  Iterable<TimeRecord> get values;
  Stream<void> get changes;
  Future<void> put(String key, TimeRecord value);
  Future<void> putAll(Map<String, TimeRecord> values);
  Future<void> delete(String key);
  Future<void> clear();
}

class HiveRecordDataStore implements RecordDataStore {
  HiveRecordDataStore(this._box);
  final Box<TimeRecord> _box;
  @override
  Iterable<TimeRecord> get values => _box.values;
  @override
  Stream<void> get changes => _box.watch().map((_) {});
  @override
  Future<void> put(String key, TimeRecord value) => _box.put(key, value);
  @override
  Future<void> putAll(Map<String, TimeRecord> values) => _box.putAll(values);
  @override
  Future<void> delete(String key) => _box.delete(key);
  @override
  Future<void> clear() => _box.clear();
}

abstract interface class CategoryDataStore {
  Iterable<Category> get values;
  bool get isEmpty;
  Category? get(String key);
  Future<void> put(String key, Category value);
  Future<void> putAll(Map<String, Category> values);
  Future<void> delete(String key);
  Future<void> clear();
}

class HiveCategoryDataStore implements CategoryDataStore {
  HiveCategoryDataStore(this._box);
  final Box<Category> _box;
  @override
  Iterable<Category> get values => _box.values;
  @override
  bool get isEmpty => _box.isEmpty;
  @override
  Category? get(String key) => _box.get(key);
  @override
  Future<void> put(String key, Category value) => _box.put(key, value);
  @override
  Future<void> putAll(Map<String, Category> values) => _box.putAll(values);
  @override
  Future<void> delete(String key) => _box.delete(key);
  @override
  Future<void> clear() => _box.clear();
}
