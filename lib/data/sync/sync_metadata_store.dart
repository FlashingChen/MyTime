import 'dart:convert';

import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';

/// Persistent boundary for synchronization-only metadata.
abstract interface class SyncMetadataStore {
  Future<SyncMetadata> read();
  Future<void> write(SyncMetadata metadata);
  Future<void> markChanged(SyncEntityKind kind, String id, DateTime changedAt);
  Future<void> markDeleted(SyncEntityKind kind, String id, DateTime deletedAt);
}

/// Stores all metadata in one private preference value.
class PreferencesSyncMetadataStore implements SyncMetadataStore {
  static const key = 'sync_metadata';
  PreferencesSyncMetadataStore(this._preferences);
  final PreferencesStore _preferences;

  @override
  Future<SyncMetadata> read() async {
    final source = await _preferences.getString(key);
    if (source == null) return const SyncMetadata();
    try {
      final root = jsonDecode(source) as Map<String, dynamic>;
      return SyncMetadata(
        records: _decode(root['records'], SyncEntityKind.record),
        categories: _decode(root['categories'], SyncEntityKind.category),
        eTag: root['eTag'] as String?,
        lastSuccessAt: root['lastSuccessAt'] == null
            ? null
            : DateTime.parse(root['lastSuccessAt'] as String).toUtc(),
      );
    } catch (_) {
      await _preferences.remove(key);
      return const SyncMetadata();
    }
  }

  @override
  Future<void> write(SyncMetadata metadata) => _preferences.setString(
    key,
    jsonEncode({
      'records': _encode(metadata.records),
      'categories': _encode(metadata.categories),
      'eTag': metadata.eTag,
      'lastSuccessAt': metadata.lastSuccessAt?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<void> markChanged(
    SyncEntityKind kind,
    String id,
    DateTime changedAt,
  ) async {
    final value = await read();
    final map = Map<String, SyncEntityMetadata>.from(_forKind(value, kind));
    final existing = map[id];
    final changed = changedAt.toUtc();
    map[id] = SyncEntityMetadata(
      kind: kind,
      id: id,
      updatedAt: existing?.updatedAt?.isAfter(changed) ?? false
          ? existing!.updatedAt
          : changed,
      deletedAt: null,
    );
    await write(_replace(value, kind, map));
  }

  @override
  Future<void> markDeleted(
    SyncEntityKind kind,
    String id,
    DateTime deletedAt,
  ) async {
    final value = await read();
    final map = Map<String, SyncEntityMetadata>.from(_forKind(value, kind));
    final existing = map[id];
    final deleted = deletedAt.toUtc();
    map[id] = SyncEntityMetadata(
      kind: kind,
      id: id,
      updatedAt: existing?.updatedAt,
      deletedAt: existing?.deletedAt?.isAfter(deleted) ?? false
          ? existing!.deletedAt
          : deleted,
    );
    await write(_replace(value, kind, map));
  }

  Map<String, SyncEntityMetadata> _forKind(
    SyncMetadata value,
    SyncEntityKind kind,
  ) => kind == SyncEntityKind.record ? value.records : value.categories;
  SyncMetadata _replace(
    SyncMetadata value,
    SyncEntityKind kind,
    Map<String, SyncEntityMetadata> map,
  ) => kind == SyncEntityKind.record
      ? value.copyWith(records: map)
      : value.copyWith(categories: map);
  Map<String, Object?> _encode(Map<String, SyncEntityMetadata> map) => {
    for (final entry in map.entries)
      entry.key: {
        'updatedAt': entry.value.updatedAt?.toUtc().toIso8601String(),
        'deletedAt': entry.value.deletedAt?.toUtc().toIso8601String(),
      },
  };
  Map<String, SyncEntityMetadata> _decode(Object? source, SyncEntityKind kind) {
    if (source == null) return {};
    final map = source as Map<String, dynamic>;
    return {
      for (final entry in map.entries)
        entry.key: SyncEntityMetadata(
          kind: kind,
          id: entry.key,
          updatedAt: entry.value['updatedAt'] == null
              ? null
              : DateTime.parse(entry.value['updatedAt'] as String).toUtc(),
          deletedAt: entry.value['deletedAt'] == null
              ? null
              : DateTime.parse(entry.value['deletedAt'] as String).toUtc(),
        ),
    };
  }
}
