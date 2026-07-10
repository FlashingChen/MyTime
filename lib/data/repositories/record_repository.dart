import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:mytime/data/models/time_record.dart';

class RecordRepository {
  final Box<TimeRecord> _box;
  final Uuid _uuid = const Uuid();

  RecordRepository(this._box);

  List<TimeRecord> getAll() {
    final records = _box.values.toList();
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  List<TimeRecord> getByDate(DateTime date) {
    return getAll().where((r) {
      return r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day;
    }).toList();
  }

  List<TimeRecord> getByRange(DateTime start, DateTime end) {
    return getAll().where((r) {
      return r.startTime.isAfter(start) && r.startTime.isBefore(end);
    }).toList();
  }

  Future<TimeRecord> add(TimeRecord record) async {
    final newRecord = TimeRecord(
      id: _uuid.v4(),
      categoryId: record.categoryId,
      startTime: record.startTime,
      endTime: record.endTime,
      note: record.note,
    );
    await _box.put(newRecord.id, newRecord);
    return newRecord;
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> update(TimeRecord record) async {
    await _box.put(record.id, record);
  }

  /// Reassign every saved record using one category to another category.
  Future<void> reassignCategory(
    String fromCategoryId,
    String toCategoryId,
  ) async {
    final updates = <String, TimeRecord>{
      for (final record in _box.values.where(
        (record) => record.categoryId == fromCategoryId,
      ))
        record.id: record.copyWith(categoryId: toCategoryId),
    };
    if (updates.isNotEmpty) await _box.putAll(updates);
  }
}
