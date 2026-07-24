import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_port.dart';

/// Selects which version survives a same-ID entity conflict.
enum SyncConflictPolicy { preferLocal, preferRemote }

/// Deterministically merges two complete documents by entity identifier.
class SyncMergeService {
  SyncMergeService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  SyncSnapshot merge({
    required SyncSnapshot local,
    required SyncSnapshot remote,
    SyncConflictPolicy conflictPolicy = SyncConflictPolicy.preferLocal,
  }) {
    final recordResult = _merge<TimeRecord>(
      local.records,
      remote.records,
      local.metadata.records,
      remote.metadata.records,
      _sameRecord,
      conflictPolicy,
    );
    final categoryResult = _merge<Category>(
      local.categories,
      remote.categories,
      local.metadata.categories,
      remote.metadata.categories,
      (a, b) => a == b,
      conflictPolicy,
    );
    final categories = categoryResult.items;
    if (categories.isEmpty) {
      throw ArgumentError('merge cannot remove every category');
    }
    final ids = categories.map((item) => item.id).toSet();
    final records = recordResult.items
        .map(
          (item) => ids.contains(item.categoryId)
              ? item
              : item.copyWith(categoryId: null),
        )
        .toList();
    return SyncSnapshot(
      records: records,
      categories: categories,
      updatedAt: _clock().toUtc(),
      metadata: SyncMetadata(
        records: _prune(recordResult.metadata),
        categories: _prune(categoryResult.metadata),
      ),
    );
  }

  _Merge<T> _merge<T extends Object>(
    Iterable<T> local,
    Iterable<T> remote,
    Map<String, SyncEntityMetadata> localMetadata,
    Map<String, SyncEntityMetadata> remoteMetadata,
    bool Function(T, T) same,
    SyncConflictPolicy conflictPolicy,
  ) {
    final left = {for (final item in local) _id(item): item};
    final right = {for (final item in remote) _id(item): item};
    final metadata = <String, SyncEntityMetadata>{
      ...localMetadata,
      ...remoteMetadata,
    };
    final result = <T>[];
    for (final id in {
      ...left.keys,
      ...right.keys,
      ...localMetadata.keys,
      ...remoteMetadata.keys,
    }) {
      final localMeta = localMetadata[id];
      final remoteMeta = remoteMetadata[id];
      final remoteWins = conflictPolicy == SyncConflictPolicy.preferRemote;
      final localDeletion = _effectiveDeletion(localMeta, null);
      final remoteDeletion = _effectiveDeletion(remoteMeta, null);
      final localEntity = localDeletion == null ? left[id] : null;
      final remoteEntity = remoteDeletion == null ? right[id] : null;
      final deletion = _resolveDeletion(
        localDeletion: localDeletion,
        remoteDeletion: remoteDeletion,
        localEntity: localEntity,
        remoteEntity: remoteEntity,
        localMetadata: localMeta,
        remoteMetadata: remoteMeta,
        conflictPolicy: conflictPolicy,
      );
      if (deletion != null) {
        metadata[id] = deletion;
        continue;
      }
      final item = remoteWins
          ? remoteEntity ?? localEntity
          : localEntity ?? remoteEntity;
      if (item != null) result.add(item);
      final chosen = remoteWins
          ? remoteEntity != null
                ? remoteMeta
                : localMeta
          : localEntity != null
          ? localMeta
          : remoteMeta;
      if (chosen?.deletedAt != null) {
        metadata.remove(id);
      } else if (chosen != null) {
        metadata[id] = chosen;
      } else {
        metadata.remove(id);
      }
    }
    return _Merge(result, metadata);
  }

  SyncEntityMetadata? _resolveDeletion<T extends Object>({
    required SyncEntityMetadata? localDeletion,
    required SyncEntityMetadata? remoteDeletion,
    required T? localEntity,
    required T? remoteEntity,
    required SyncEntityMetadata? localMetadata,
    required SyncEntityMetadata? remoteMetadata,
    required SyncConflictPolicy conflictPolicy,
  }) {
    if (localDeletion == null && remoteDeletion == null) return null;
    if (localEntity == null && remoteEntity == null) {
      return _effectiveDeletion(localDeletion, remoteDeletion);
    }
    final remoteWins = conflictPolicy == SyncConflictPolicy.preferRemote;
    final deletion = _effectiveDeletion(localDeletion, remoteDeletion)!;
    final entity = remoteWins
        ? remoteEntity ?? localEntity
        : localEntity ?? remoteEntity;
    final entityMetadata = identical(entity, remoteEntity)
        ? remoteMetadata
        : localMetadata;
    final updatedAt = entityMetadata?.updatedAt;
    if (updatedAt != null) {
      final comparison = deletion.deletedAt!.toUtc().compareTo(
        updatedAt.toUtc(),
      );
      if (comparison > 0) return deletion;
      if (comparison < 0) return null;
    }
    final preferredDeletion = remoteWins ? remoteDeletion : localDeletion;
    return preferredDeletion;
  }

  SyncEntityMetadata? _effectiveDeletion(
    SyncEntityMetadata? a,
    SyncEntityMetadata? b,
  ) {
    final candidates = [a, b]
        .where((item) => item?.deletedAt != null)
        .cast<SyncEntityMetadata>()
        .where(
          (item) => !item.deletedAt!.isBefore(
            _clock().toUtc().subtract(const Duration(days: 90)),
          ),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (left, right) => left.deletedAt!.compareTo(right.deletedAt!),
    );
    return candidates.last;
  }

  Map<String, SyncEntityMetadata> _prune(
    Map<String, SyncEntityMetadata> value,
  ) {
    final cutoff = _clock().toUtc().subtract(const Duration(days: 90));
    return {
      for (final entry in value.entries)
        if (entry.value.deletedAt == null ||
            !entry.value.deletedAt!.isBefore(cutoff))
          entry.key: entry.value,
    };
  }

  String _id(Object item) => switch (item) {
    TimeRecord value => value.id,
    Category value => value.id,
    _ => throw ArgumentError.value(item),
  };
  bool _sameRecord(TimeRecord a, TimeRecord b) =>
      a.id == b.id &&
      a.categoryId == b.categoryId &&
      a.startTime == b.startTime &&
      a.endTime == b.endTime &&
      a.note == b.note &&
      a.createdAt == b.createdAt;
}

class _Merge<T> {
  const _Merge(this.items, this.metadata);
  final List<T> items;
  final Map<String, SyncEntityMetadata> metadata;
}
