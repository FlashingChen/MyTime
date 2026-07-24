import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:equatable/equatable.dart';

/// Remote document accompanied by the entity metadata and HTTP ETag that read it.
class RemoteSyncDocument {
  const RemoteSyncDocument({required this.snapshot, this.eTag});
  final SyncSnapshot snapshot;
  final String? eTag;
}

/// A WebDAV lock token obtained for a short synchronization transaction.
class SyncLock {
  const SyncLock(this.token);
  final String token;
}

/// The document changed after it was read and must be merged again.
class SyncPreconditionFailed implements Exception {
  const SyncPreconditionFailed();
}

/// Immutable local dataset exchanged with a remote sync provider.
class SyncSnapshot extends Equatable {
  SyncSnapshot({
    required Iterable<TimeRecord> records,
    required Iterable<Category> categories,
    required this.updatedAt,
    this.metadata = const SyncMetadata(),
  }) : records = List.unmodifiable(records),
       categories = List.unmodifiable(categories);

  final List<TimeRecord> records;
  final List<Category> categories;
  final DateTime updatedAt;
  final SyncMetadata metadata;

  @override
  List<Object?> get props => [
    records.map((record) => [record, record.createdAt]).toList(),
    categories,
    updatedAt,
    metadata,
  ];

  /// Verifies that this snapshot can be safely persisted as a complete dataset.
  void validate() {
    if (categories.isEmpty) {
      throw ArgumentError.value(
        categories,
        'categories',
        'must contain at least one category',
      );
    }
    final categoryIds = <String>{};
    for (final category in categories) {
      if (category.id.trim().isEmpty) {
        throw ArgumentError.value(
          category.id,
          'category.id',
          'must not be blank',
        );
      }
      if (!categoryIds.add(category.id)) {
        throw ArgumentError.value(category.id, 'category.id', 'must be unique');
      }
      if (category.name.trim().isEmpty) {
        throw ArgumentError.value(
          category.name,
          'category.name',
          'must not be blank',
        );
      }
      if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(category.color)) {
        throw ArgumentError.value(
          category.color,
          'category.color',
          'must be a #RRGGBB color',
        );
      }
    }

    final recordIds = <String>{};
    for (final record in records) {
      if (record.id.trim().isEmpty) {
        throw ArgumentError.value(record.id, 'record.id', 'must not be blank');
      }
      if (!recordIds.add(record.id)) {
        throw ArgumentError.value(record.id, 'record.id', 'must be unique');
      }
      if (!record.endTime.isAfter(record.startTime)) {
        throw ArgumentError.value(
          record.endTime,
          'record.endTime',
          'must be after startTime',
        );
      }
      final categoryId = record.categoryId;
      if (categoryId != null && !categoryIds.contains(categoryId)) {
        throw ArgumentError.value(
          categoryId,
          'record.categoryId',
          'must refer to a category in the snapshot',
        );
      }
    }
  }
}

/// Storage-agnostic boundary for one remote synchronization target.
abstract interface class SyncPort {
  Future<RemoteSyncDocument?> pull();
  Future<String?> push(
    SyncSnapshot snapshot, {
    required String? ifMatch,
    required bool ifNoneMatch,
  });
  Future<SyncLock?> lock();
  Future<void> unlock(SyncLock lock);
}
