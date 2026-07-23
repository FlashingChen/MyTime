import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_port.dart';

/// Deterministically merges two complete documents by entity identifier.
class SyncMergeService {
  SyncMergeService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;

  SyncSnapshot merge({
    required SyncSnapshot local,
    required SyncSnapshot remote,
  }) {
    final recordResult = _merge<TimeRecord>(
      local.records,
      remote.records,
      local.metadata.records,
      remote.metadata.records,
      _sameRecord,
    );
    final categoryResult = _merge<Category>(
      local.categories,
      remote.categories,
      local.metadata.categories,
      remote.metadata.categories,
      (a, b) => a == b,
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
      final deleted = _effectiveDeletion(localMeta, remoteMeta);
      if (deleted != null) {
        metadata[id] = deleted;
        continue;
      }
      final a = left[id];
      final b = right[id];
      if (a != null && b != null) {
        result.add(same(a, b) ? a : a);
      } else if (a != null) {
        result.add(a);
      } else if (b != null) {
        result.add(b);
      }
      final chosen = localMeta ?? remoteMeta;
      if (chosen != null) metadata[id] = chosen;
    }
    return _Merge(result, metadata);
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
    final deletion = candidates.last;
    final latestUpdate = [a?.updatedAt, b?.updatedAt]
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, value) =>
              latest == null || value.isAfter(latest) ? value : latest,
        );
    return latestUpdate == null || deletion.deletedAt!.isAfter(latestUpdate)
        ? deletion
        : null;
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
