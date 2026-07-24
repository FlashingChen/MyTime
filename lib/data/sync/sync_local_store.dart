import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';

/// Storage-agnostic boundary for reading and failure-safely replacing local data.
abstract interface class SyncLocalStore {
  /// Runs a complete sync transaction without interleaved local mutations.
  Future<T> runExclusive<T>(Future<T> Function() operation);

  /// Returns the complete local dataset and its last local mutation timestamp.
  Future<SyncSnapshot> read();

  /// Returns a local snapshot without repository-side initialization.
  Future<SyncSnapshot> readReadOnly();

  /// Validates and replaces the complete local dataset or restores the old one.
  Future<void> replace(SyncSnapshot snapshot);

  /// Replaces [snapshot] only if the local revision is still [expectedUpdatedAt].
  ///
  /// The comparison and replacement are atomic with application-originated
  /// writes, preventing a slow remote pull from overwriting new local data.
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot snapshot,
  );
}

/// [SyncLocalStore] adapter backed by the application repository ports.
///
/// It avoids direct Hive access and stages an upsert-before-delete replacement.
/// If any repository or revision write fails, it restores the snapshot read
/// before the attempt. A failed restore is surfaced as [SyncRollbackException].
class RepositorySyncLocalStore implements SyncLocalStore {
  RepositorySyncLocalStore({
    required RecordsRepository records,
    required CategoriesRepository categories,
    required SyncRevisionStore revision,
    SyncMetadataStore? metadata,
    SyncDataGate? gate,
    Future<List<TimeRecord>> Function()? readOnlyRecords,
    Future<List<Category>> Function()? readOnlyCategories,
  }) : _records = records,
       _categories = categories,
       _revision = revision,
       _metadata = metadata,
       _gate = gate ?? SyncDataGate(),
       _readOnlyRecords = readOnlyRecords ?? (() async => records.getAll()),
       _readOnlyCategories =
           readOnlyCategories ?? (() async => categories.getAll());

  final RecordsRepository _records;
  final CategoriesRepository _categories;
  final SyncRevisionStore _revision;
  final SyncMetadataStore? _metadata;
  final SyncDataGate _gate;
  final Future<List<TimeRecord>> Function() _readOnlyRecords;
  final Future<List<Category>> Function() _readOnlyCategories;

  @override
  Future<T> runExclusive<T>(Future<T> Function() operation) =>
      _gate.run(operation);

  @override
  Future<SyncSnapshot> read() => _gate.run(_readUnlocked);

  @override
  Future<SyncSnapshot> readReadOnly() => _gate.run(() async {
    return SyncSnapshot(
      records: await _readOnlyRecords(),
      categories: await _readOnlyCategories(),
      updatedAt: await _revision.readUpdatedAt(),
      metadata: await _metadata?.read() ?? const SyncMetadata(),
    );
  });

  Future<SyncSnapshot> _readUnlocked() async {
    final snapshot = SyncSnapshot(
      records: _records.getAll(),
      categories: _categories.getAll(),
      updatedAt: await _revision.readUpdatedAt(),
      metadata: await _metadata?.read() ?? const SyncMetadata(),
    );
    snapshot.validate();
    return snapshot;
  }

  @override
  Future<void> replace(SyncSnapshot snapshot) =>
      _gate.run(() => _replaceUnlocked(snapshot));

  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot snapshot,
  ) {
    return _gate.run(() async {
      final current = await _revision.readUpdatedAt();
      if (current.toUtc() != expectedUpdatedAt.toUtc()) return false;
      await _replaceUnlocked(snapshot);
      return true;
    });
  }

  Future<void> _replaceUnlocked(SyncSnapshot snapshot) async {
    snapshot.validate();
    final previous = await _readUnlocked();

    try {
      await _writeSnapshot(snapshot);
      await _revision.writeUpdatedAt(snapshot.updatedAt);
      await _metadata?.write(snapshot.metadata);
    } catch (error, stackTrace) {
      try {
        await _writeSnapshot(previous);
        await _revision.writeUpdatedAt(previous.updatedAt);
        await _metadata?.write(previous.metadata);
      } catch (rollbackError, rollbackStackTrace) {
        throw SyncRollbackException(
          cause: error,
          causeStackTrace: stackTrace,
          rollbackError: rollbackError,
          rollbackStackTrace: rollbackStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Advances the local revision after a successful local mutation.
  ///
  /// Older values are ignored so clock skew or delayed events cannot make a
  /// newer local snapshot appear stale.
  Future<void> markLocalChanged(DateTime updatedAt) async {
    final current = (await _revision.readUpdatedAt()).toUtc();
    final candidate = updatedAt.toUtc();
    final next = candidate.isAfter(current)
        ? candidate
        : current.add(const Duration(microseconds: 1));
    await _revision.writeUpdatedAt(next);
  }

  Future<void> _writeSnapshot(SyncSnapshot snapshot) async {
    final existingCategories = {
      for (final category in _categories.getAll()) category.id: category,
    };
    final existingRecords = {
      for (final record in _records.getAll()) record.id: record,
    };

    final targetCategories = {
      for (final category in snapshot.categories) category.id: category,
    };
    final targetRecords = {
      for (final record in snapshot.records) record.id: record,
    };

    // Add all categories before records so every target relation exists.
    for (final category in snapshot.categories) {
      final existing = existingCategories[category.id];
      if (existing == null) {
        await _categories.add(category);
      } else if (existing != category) {
        await _categories.update(category);
      }
    }

    for (final record in snapshot.records) {
      final existing = existingRecords[record.id];
      if (existing == null) {
        await _records.add(record);
      } else if (!_sameRecord(existing, record)) {
        await _records.update(record);
      }
    }

    // Delete only after every target item has been written successfully.
    for (final record in existingRecords.values) {
      if (!targetRecords.containsKey(record.id)) {
        await _records.delete(record.id);
      }
    }
    for (final category in existingCategories.values) {
      if (!targetCategories.containsKey(category.id)) {
        await _categories.delete(category.id);
      }
    }
  }

  bool _sameRecord(TimeRecord left, TimeRecord right) {
    return left.id == right.id &&
        left.categoryId == right.categoryId &&
        left.startTime == right.startTime &&
        left.endTime == right.endTime &&
        left.note == right.note &&
        left.createdAt == right.createdAt;
  }
}

/// Indicates that an unsuccessful local replacement could not be restored.
class SyncRollbackException implements Exception {
  const SyncRollbackException({
    required this.cause,
    required this.causeStackTrace,
    required this.rollbackError,
    required this.rollbackStackTrace,
  });

  final Object cause;
  final StackTrace causeStackTrace;
  final Object rollbackError;
  final StackTrace rollbackStackTrace;

  @override
  String toString() {
    return 'SyncRollbackException(cause: $cause, rollbackError: '
        '$rollbackError)';
  }
}
