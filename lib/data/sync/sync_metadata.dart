/// Kinds of domain entities tracked by synchronization metadata.
enum SyncEntityKind { record, category }

/// Revision or deletion information for one synchronized entity.
class SyncEntityMetadata {
  const SyncEntityMetadata({
    required this.kind,
    required this.id,
    this.updatedAt,
    this.deletedAt,
  });

  final SyncEntityKind kind;
  final String id;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  SyncEntityMetadata copyWith({DateTime? updatedAt, DateTime? deletedAt}) =>
      SyncEntityMetadata(
        kind: kind,
        id: id,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );
}

/// Metadata exchanged with a WebDAV document but kept out of domain entities.
class SyncMetadata {
  const SyncMetadata({
    this.records = const {},
    this.categories = const {},
    this.eTag,
    this.lastSuccessAt,
  });

  final Map<String, SyncEntityMetadata> records;
  final Map<String, SyncEntityMetadata> categories;
  final String? eTag;
  final DateTime? lastSuccessAt;

  SyncMetadata copyWith({
    Map<String, SyncEntityMetadata>? records,
    Map<String, SyncEntityMetadata>? categories,
    String? eTag,
    DateTime? lastSuccessAt,
  }) => SyncMetadata(
    records: records ?? this.records,
    categories: categories ?? this.categories,
    eTag: eTag ?? this.eTag,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
  );
}
