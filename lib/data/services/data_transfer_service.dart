import 'dart:convert';

import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_metadata.dart';

/// Validates and atomically imports a MyTime JSON backup.
class DataTransferService {
  DataTransferService(
    this._records,
    this._categories, {
    SyncMutationMarker? mutationMarker,
    SyncDataGate? gate,
    Future<void> Function()? refreshSnapshot,
  }) : _mutationMarker = mutationMarker,
       _gate = gate ?? SyncDataGate(),
       _refreshSnapshot = refreshSnapshot;

  final RecordsSnapshotRepository _records;
  final CategoriesSnapshotRepository _categories;
  final SyncMutationMarker? _mutationMarker;
  final SyncDataGate _gate;
  final Future<void> Function()? _refreshSnapshot;

  Future<ImportResult> importJson(String source) async {
    final backup = _parse(source);
    return _gate.run(() => _import(backup));
  }

  Future<ImportResult> _import(_Backup backup) async {
    final previousRecords = _records.getAll();
    final previousCategories = _categories.getAll();
    try {
      await _categories.replaceAll(backup.categories);
      await _records.replaceAll(backup.records);
      await _markImportedChanges(
        previousRecords: previousRecords,
        previousCategories: previousCategories,
        records: backup.records,
        categories: backup.categories,
      );
      await _refreshSnapshot?.call();
      return ImportResult(backup.records.length, backup.categories.length);
    } catch (_) {
      await _categories.replaceAll(previousCategories);
      await _records.replaceAll(previousRecords);
      rethrow;
    }
  }

  Future<void> _markImportedChanges({
    required List<TimeRecord> previousRecords,
    required List<Category> previousCategories,
    required List<TimeRecord> records,
    required List<Category> categories,
  }) async {
    final marker = _mutationMarker;
    if (marker is! SyncEntityMutationMarker) {
      await marker?.markLocalChanged();
      return;
    }
    final previousRecordIds = previousRecords.map((item) => item.id).toSet();
    final previousCategoryIds = previousCategories
        .map((item) => item.id)
        .toSet();
    final recordIds = records.map((item) => item.id).toSet();
    final categoryIds = categories.map((item) => item.id).toSet();
    for (final id in previousRecordIds.difference(recordIds)) {
      await marker.markDeleted(SyncEntityKind.record, id);
    }
    for (final id in previousCategoryIds.difference(categoryIds)) {
      await marker.markDeleted(SyncEntityKind.category, id);
    }
    for (final id in recordIds) {
      await marker.markChanged(SyncEntityKind.record, id);
    }
    for (final id in categoryIds) {
      await marker.markChanged(SyncEntityKind.category, id);
    }
  }

  _Backup _parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('仅支持版本为 1 的 MyTime 备份文件。');
    }
    final rawCategories = decoded['categories'];
    final rawRecords = decoded['records'];
    if (rawCategories is! List || rawRecords is! List) {
      throw const FormatException('备份必须包含 categories 和 records 数组。');
    }
    final categories = rawCategories.map(_category).toList(growable: false);
    if (categories.isEmpty) {
      throw const FormatException('备份至少需要保留一个分类。');
    }
    if (categories.map((item) => item.id).toSet().length != categories.length) {
      throw const FormatException('备份中存在重复的分类 ID。');
    }
    final categoryIds = categories.map((item) => item.id).toSet();
    final records = rawRecords
        .map((item) => _record(item, categoryIds))
        .toList(growable: false);
    if (records.map((item) => item.id).toSet().length != records.length) {
      throw const FormatException('备份中存在重复的记录 ID。');
    }
    return _Backup(categories, records);
  }

  Category _category(Object? source) {
    if (source is! Map) throw const FormatException('分类格式无效。');
    final id = source['id'];
    final name = source['name'];
    final color = source['color'];
    if (id is! String || id.isEmpty || name is! String || color is! String) {
      throw const FormatException('分类缺少有效字段。');
    }
    return Category(id: id, name: name, color: color);
  }

  TimeRecord _record(Object? source, Set<String> categoryIds) {
    if (source is! Map) throw const FormatException('记录格式无效。');
    final id = source['id'];
    final categoryId = source['categoryId'];
    final start = source['startTime'];
    final end = source['endTime'];
    final note = source['note'];
    if (id is! String ||
        id.isEmpty ||
        start is! String ||
        end is! String ||
        (categoryId != null && categoryId is! String) ||
        (note != null && note is! String)) {
      throw const FormatException('记录缺少有效字段。');
    }
    final startTime = DateTime.tryParse(start);
    final endTime = DateTime.tryParse(end);
    if (startTime == null || endTime == null || !endTime.isAfter(startTime)) {
      throw const FormatException('记录时间范围无效。');
    }
    if (categoryId is String && !categoryIds.contains(categoryId)) {
      throw const FormatException('记录引用了不存在的分类。');
    }
    return TimeRecord(
      id: id,
      categoryId: categoryId as String?,
      startTime: startTime,
      endTime: endTime,
      note: note as String?,
    );
  }
}

class ImportResult {
  const ImportResult(this.recordCount, this.categoryCount);
  final int recordCount;
  final int categoryCount;
}

class _Backup {
  const _Backup(this.categories, this.records);
  final List<Category> categories;
  final List<TimeRecord> records;
}
