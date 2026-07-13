import 'package:uuid/uuid.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';

/// Application-facing port for persisted time records.
abstract interface class RecordsRepository {
  Stream<void> get changes;
  List<TimeRecord> getAll();
  List<TimeRecord> getByDate(DateTime date);
  List<TimeRecord> getByRange(DateTime start, DateTime end);
  Future<TimeRecord> add(TimeRecord record);
  Future<void> delete(String id);
  Future<void> update(TimeRecord record);
  Future<void> reassignCategory(String fromCategoryId, String toCategoryId);
  Future<void> clearCategory(String categoryId);
}

/// Extends [RecordsRepository] with complete-dataset replacement for imports.
abstract interface class RecordsSnapshotRepository
    implements RecordsRepository {
  Future<void> replaceAll(Iterable<TimeRecord> records);
}

/// DataStore-backed implementation of [RecordsSnapshotRepository].
class RecordRepository implements RecordsSnapshotRepository {
  final RecordDataStore _store;
  final Uuid _uuid = const Uuid();

  RecordRepository.withStore(this._store);

  /// Emits whenever a persisted record is added, changed, or deleted.
  @override
  Stream<void> get changes => _store.changes;

  @override
  List<TimeRecord> getAll() {
    final records = _store.values.toList();
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  @override
  List<TimeRecord> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getAll().where((r) {
      return r.startTime.isBefore(end) && r.endTime.isAfter(start);
    }).toList();
  }

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) {
    return getAll().where((r) {
      return r.startTime.isBefore(end) && r.endTime.isAfter(start);
    }).toList();
  }

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    _validate(record);
    final newRecord = TimeRecord(
      id: record.id.isEmpty ? _uuid.v4() : record.id,
      categoryId: record.categoryId,
      startTime: record.startTime,
      endTime: record.endTime,
      note: record.note,
      createdAt: record.createdAt,
    );
    await _store.put(newRecord.id, newRecord);
    return newRecord;
  }

  @override
  Future<void> delete(String id) async {
    await _store.delete(id);
  }

  @override
  Future<void> update(TimeRecord record) async {
    _validate(record);
    await _store.put(record.id, record);
  }

  /// Reassign every saved record using one category to another category.
  @override
  Future<void> reassignCategory(
    String fromCategoryId,
    String toCategoryId,
  ) async {
    final updates = <String, TimeRecord>{
      for (final record in _store.values.where(
        (record) => record.categoryId == fromCategoryId,
      ))
        record.id: record.copyWith(categoryId: toCategoryId),
    };
    if (updates.isNotEmpty) await _store.putAll(updates);
  }

  /// Clear the category of every saved record using the given category.
  @override
  Future<void> clearCategory(String categoryId) async {
    final updates = <String, TimeRecord>{
      for (final record in _store.values.where(
        (record) => record.categoryId == categoryId,
      ))
        record.id: record.copyWith(categoryId: null),
    };
    if (updates.isNotEmpty) await _store.putAll(updates);
  }

  /// Replaces all records, used only after a complete import was validated.
  @override
  Future<void> replaceAll(Iterable<TimeRecord> records) async {
    final values = <String, TimeRecord>{};
    for (final record in records) {
      _validate(record);
      final id = record.id.isEmpty ? _uuid.v4() : record.id;
      values[id] = record.copyWith(id: id);
    }
    await _store.clear();
    if (values.isNotEmpty) await _store.putAll(values);
  }

  void _validate(TimeRecord record) {
    if (!record.endTime.isAfter(record.startTime)) {
      throw ArgumentError.value(
        record.endTime,
        'endTime',
        'must be after startTime',
      );
    }
  }
}
