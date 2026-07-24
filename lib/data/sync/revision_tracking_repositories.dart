import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_metadata.dart';

/// Decorates [RecordsRepository] without changing its application-facing port.
///
/// Successful local writes advance [SyncMutationMarker]. Remote snapshot
/// application deliberately uses the undecorated repository instead, so it
/// retains the remote revision rather than becoming a new local change.
class RevisionTrackingRecordsRepository implements RecordsRepository {
  RevisionTrackingRecordsRepository({
    required RecordsRepository delegate,
    required SyncMutationMarker marker,
    SyncDataGate? gate,
  }) : _delegate = delegate,
       _marker = marker,
       _gate = gate ?? SyncDataGate();

  final RecordsRepository _delegate;
  final SyncMutationMarker _marker;
  final SyncDataGate _gate;

  @override
  Stream<void> get changes => _delegate.changes;

  @override
  List<TimeRecord> getAll() => _delegate.getAll();

  @override
  List<TimeRecord> getByDate(DateTime date) => _delegate.getByDate(date);

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) =>
      _delegate.getByRange(start, end);

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    return _gate.run(() async {
      final result = await _delegate.add(record);
      if (_marker case final SyncEntityMutationMarker marker) {
        await marker.markChanged(SyncEntityKind.record, result.id);
      } else {
        await _marker.markLocalChanged();
      }
      return result;
    });
  }

  @override
  Future<void> delete(String id) =>
      _afterLocalWrite(() => _delegate.delete(id), id, deleted: true);

  @override
  Future<void> update(TimeRecord record) =>
      _afterLocalWrite(() => _delegate.update(record), record.id);

  @override
  Future<void> reassignCategory(String fromCategoryId, String toCategoryId) =>
      _afterAffectedRecords(
        () => _delegate.reassignCategory(fromCategoryId, toCategoryId),
        fromCategoryId,
      );

  @override
  Future<void> clearCategory(String categoryId) => _afterAffectedRecords(
    () => _delegate.clearCategory(categoryId),
    categoryId,
  );

  Future<void> _afterAffectedRecords(
    Future<void> Function() operation,
    String categoryId,
  ) async {
    final affected = _delegate
        .getAll()
        .where((record) => record.categoryId == categoryId)
        .map((record) => record.id)
        .toList();
    return _gate.run(() async {
      await operation();
      if (_marker case final SyncEntityMutationMarker marker) {
        for (final id in affected) {
          await marker.markChanged(SyncEntityKind.record, id);
        }
      } else {
        await _marker.markLocalChanged();
      }
    });
  }

  Future<T> _afterLocalWrite<T>(
    Future<T> Function() operation,
    String id, {
    bool deleted = false,
  }) async {
    return _gate.run(() async {
      final result = await operation();
      if (_marker case final SyncEntityMutationMarker marker) {
        if (deleted) {
          await marker.markDeleted(SyncEntityKind.record, id);
        } else {
          await marker.markChanged(SyncEntityKind.record, id);
        }
      } else {
        await _marker.markLocalChanged();
      }
      return result;
    });
  }
}

/// Decorates [CategoriesRepository] without changing its application-facing
/// port.
class RevisionTrackingCategoriesRepository implements CategoriesRepository {
  RevisionTrackingCategoriesRepository({
    required CategoriesRepository delegate,
    required SyncMutationMarker marker,
    SyncDataGate? gate,
  }) : _delegate = delegate,
       _marker = marker,
       _gate = gate ?? SyncDataGate();

  final CategoriesRepository _delegate;
  final SyncMutationMarker _marker;
  final SyncDataGate _gate;

  @override
  List<Category> getAll() => _delegate.getAll();

  @override
  Category? getById(String id) => _delegate.getById(id);

  @override
  Future<Category> add(Category category) async {
    return _gate.run(() async {
      final result = await _delegate.add(category);
      if (_marker case final SyncEntityMutationMarker marker) {
        await marker.markChanged(SyncEntityKind.category, result.id);
      } else {
        await _marker.markLocalChanged();
      }
      return result;
    });
  }

  @override
  Future<void> update(Category category) =>
      _afterLocalWrite(() => _delegate.update(category), category.id);

  @override
  Future<void> delete(String id) =>
      _afterLocalWrite(() => _delegate.delete(id), id, deleted: true);

  Future<T> _afterLocalWrite<T>(
    Future<T> Function() operation,
    String id, {
    bool deleted = false,
  }) async {
    return _gate.run(() async {
      final result = await operation();
      if (_marker case final SyncEntityMutationMarker marker) {
        if (deleted) {
          await marker.markDeleted(SyncEntityKind.category, id);
        } else {
          await marker.markChanged(SyncEntityKind.category, id);
        }
      } else {
        await _marker.markLocalChanged();
      }
      return result;
    });
  }
}
