import 'dart:async';
import 'dart:convert';

import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_port.dart';

/// Persists the complete background-safe synchronization snapshot in preferences.
class PreferencesSyncSnapshotStore implements SyncLocalStore {
  static const key = 'sync_snapshot_v2';

  PreferencesSyncSnapshotStore(this._preferences);

  final PreferencesStore _preferences;
  Future<void> _tail = Future<void>.value();
  static final Object _zoneKey = Object();

  /// Returns no value when no valid background snapshot has been persisted.
  Future<SyncSnapshot?> readSnapshot() async {
    final source = await _preferences.getString(key);
    if (source == null) return null;
    try {
      return _decode(source);
    } catch (_) {
      await _preferences.remove(key);
      return null;
    }
  }

  /// Replaces the foreground-owned entity payload while retaining sync metadata.
  Future<SyncSnapshot> reconcileForeground(SyncSnapshot foreground) async {
    final retained = await readSnapshot();
    final reconciled = SyncSnapshot(
      records: foreground.records,
      categories: foreground.categories,
      updatedAt: foreground.updatedAt,
      metadata: retained?.metadata ?? foreground.metadata,
    );
    await write(reconciled);
    return reconciled;
  }

  Future<void> write(SyncSnapshot snapshot) {
    snapshot.validate();
    return _preferences.setString(key, jsonEncode(_encode(snapshot)));
  }

  /// Captures the exact persisted value for transactional foreground rollback.
  Future<String?> captureSerialized() => _preferences.getString(key);

  /// Restores a value captured by [captureSerialized] without rebuilding it.
  Future<void> restoreSerialized(String? source) => source == null
      ? _preferences.remove(key)
      : _preferences.setString(key, source);

  @override
  Future<T> runExclusive<T>(Future<T> Function() operation) {
    if (Zone.current[_zoneKey] == this) return operation();
    final queued = _tail.then<T>(
      (_) => runZoned(operation, zoneValues: {_zoneKey: this}),
    );
    _tail = queued.then<void>((_) {}, onError: (_, __) {});
    return queued;
  }

  @override
  Future<SyncSnapshot> read() async =>
      await readSnapshot() ?? (throw StateError('No persisted sync snapshot'));

  @override
  Future<SyncSnapshot> readReadOnly() async {
    final source = await _preferences.getString(key);
    if (source == null) {
      throw StateError('No persisted sync snapshot');
    }
    return _decode(source);
  }

  @override
  Future<void> replace(SyncSnapshot snapshot) =>
      runExclusive(() => write(snapshot));

  @override
  Future<bool> replaceIfCurrent(
    DateTime expectedUpdatedAt,
    SyncSnapshot snapshot,
  ) {
    return runExclusive(() async {
      final current = await read();
      if (current.updatedAt.toUtc() != expectedUpdatedAt.toUtc()) return false;
      await write(snapshot);
      return true;
    });
  }

  static Map<String, Object?> _encode(SyncSnapshot snapshot) => {
    'version': 2,
    'updatedAt': snapshot.updatedAt.toUtc().toIso8601String(),
    'categories': [
      for (final item in snapshot.categories)
        {'id': item.id, 'name': item.name, 'color': item.color},
    ],
    'records': [
      for (final item in snapshot.records)
        {
          'id': item.id,
          'categoryId': item.categoryId,
          'startTime': item.startTime.toUtc().toIso8601String(),
          'endTime': item.endTime.toUtc().toIso8601String(),
          'note': item.note,
          'createdAt': item.createdAt.toUtc().toIso8601String(),
        },
    ],
    'metadata': {
      'eTag': snapshot.metadata.eTag,
      'lastSuccessAt': snapshot.metadata.lastSuccessAt
          ?.toUtc()
          .toIso8601String(),
      'records': _encodeMetadata(snapshot.metadata.records),
      'categories': _encodeMetadata(snapshot.metadata.categories),
    },
  };

  static Map<String, Object?> _encodeMetadata(
    Map<String, SyncEntityMetadata> values,
  ) => {
    for (final entry in values.entries)
      entry.key: {
        'updatedAt': entry.value.updatedAt?.toUtc().toIso8601String(),
        'deletedAt': entry.value.deletedAt?.toUtc().toIso8601String(),
      },
  };

  static SyncSnapshot _decode(String source) {
    final root = _map(jsonDecode(source), 'snapshot');
    if (root['version'] != 2) {
      throw const FormatException('Unsupported snapshot');
    }
    final metadata = _map(root['metadata'], 'metadata');
    final snapshot = SyncSnapshot(
      updatedAt: _date(root['updatedAt']),
      categories: _list(root['categories'], 'categories').map(_category),
      records: _list(root['records'], 'records').map(_record),
      metadata: SyncMetadata(
        eTag: _nullableString(metadata['eTag']),
        lastSuccessAt: _nullableDate(metadata['lastSuccessAt']),
        records: _decodeMetadata(metadata['records'], SyncEntityKind.record),
        categories: _decodeMetadata(
          metadata['categories'],
          SyncEntityKind.category,
        ),
      ),
    );
    snapshot.validate();
    return snapshot;
  }

  static Map<String, SyncEntityMetadata> _decodeMetadata(
    Object? source,
    SyncEntityKind kind,
  ) => {
    for (final entry in _map(source, 'metadata entries').entries)
      entry.key: SyncEntityMetadata(
        kind: kind,
        id: entry.key,
        updatedAt: _nullableDate(
          _map(entry.value, 'metadata entry')['updatedAt'],
        ),
        deletedAt: _nullableDate(
          _map(entry.value, 'metadata entry')['deletedAt'],
        ),
      ),
  };

  static Category _category(Object? source) {
    final value = _map(source, 'category');
    return Category(
      id: _string(value['id']),
      name: _string(value['name']),
      color: _string(value['color']),
    );
  }

  static TimeRecord _record(Object? source) {
    final value = _map(source, 'record');
    return TimeRecord(
      id: _string(value['id']),
      categoryId: _nullableString(value['categoryId']),
      startTime: _date(value['startTime']),
      endTime: _date(value['endTime']),
      note: _nullableString(value['note']),
      createdAt: _date(value['createdAt']),
    );
  }

  static Map<String, Object?> _map(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object');
    return {
      for (final entry in value.entries) entry.key as String: entry.value,
    };
  }

  static List<Object?> _list(Object? value, String name) {
    if (value is! List) throw FormatException('$name must be an array');
    return List<Object?>.from(value);
  }

  static String _string(Object? value) {
    if (value is! String) throw const FormatException('Expected string');
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value != null && value is! String) {
      throw const FormatException('Expected string');
    }
    return value as String?;
  }

  static DateTime _date(Object? value) =>
      DateTime.parse(_string(value)).toUtc();

  static DateTime? _nullableDate(Object? value) =>
      value == null ? null : _date(value);
}
