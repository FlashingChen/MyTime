import 'dart:convert';

import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/preferences_sync_snapshot_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';

/// Persists the pre-import state until an import is fully committed.
class ImportRecoveryJournal {
  static const key = 'import_recovery_v1';

  ImportRecoveryJournal(this._preferences);

  final PreferencesStore _preferences;

  Future<void> save({
    required Iterable<TimeRecord> records,
    required Iterable<Category> categories,
    String? syncSnapshot,
    String? revision,
    String? metadata,
    String? pendingRevision,
  }) async {
    await _preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'records': [for (final record in records) _encodeRecord(record)],
        'categories': [
          for (final category in categories) _encodeCategory(category),
        ],
        'syncSnapshot':
            syncSnapshot ??
            await _preferences.getString(PreferencesSyncSnapshotStore.key),
        'revision':
            revision ??
            await _preferences.getString(
              PreferencesSyncRevisionStore.updatedAtKey,
            ),
        'metadata':
            metadata ??
            await _preferences.getString(PreferencesSyncMetadataStore.key),
        'pendingRevision':
            pendingRevision ??
            await _preferences.getString(PreferencesSyncPendingStateStore.key),
      }),
    );
  }

  Future<ImportRecovery?> read() async {
    final source = await _preferences.getString(key);
    if (source == null) return null;
    try {
      final root = jsonDecode(source);
      if (root is! Map || root['version'] != 1) throw const FormatException();
      final records = _list(root['records']).map(_decodeRecord).toList();
      final categories = _list(
        root['categories'],
      ).map(_decodeCategory).toList();
      return ImportRecovery(
        records: records,
        categories: categories,
        syncSnapshot: root['syncSnapshot'] as String?,
        revision: root['revision'] as String?,
        metadata: root['metadata'] as String?,
        pendingRevision: root['pendingRevision'] as String?,
      );
    } catch (_) {
      throw StateError('Invalid import recovery journal');
    }
  }

  Future<bool> hasPendingRecovery() async => await read() != null;

  Future<void> clear() => _preferences.remove(key);

  Future<void> restorePreferences(ImportRecovery recovery) async {
    Object? failure;
    StackTrace? stackTrace;
    Future<void> attempt(Future<void> Function() operation) async {
      try {
        await operation();
      } catch (error, trace) {
        failure ??= error;
        stackTrace ??= trace;
      }
    }

    await attempt(
      () => _restore(PreferencesSyncSnapshotStore.key, recovery.syncSnapshot),
    );
    await attempt(
      () => _restore(
        PreferencesSyncRevisionStore.updatedAtKey,
        recovery.revision,
      ),
    );
    await attempt(
      () => _restore(PreferencesSyncMetadataStore.key, recovery.metadata),
    );
    await attempt(
      () => _restore(
        PreferencesSyncPendingStateStore.key,
        recovery.pendingRevision,
      ),
    );
    if (failure != null) Error.throwWithStackTrace(failure!, stackTrace!);
  }

  Future<void> _restore(String key, String? value) => value == null
      ? _preferences.remove(key)
      : _preferences.setString(key, value);

  static Map<String, Object?> _encodeRecord(TimeRecord record) => {
    'id': record.id,
    'categoryId': record.categoryId,
    'startTime': record.startTime.toUtc().toIso8601String(),
    'endTime': record.endTime.toUtc().toIso8601String(),
    'note': record.note,
    'createdAt': record.createdAt.toUtc().toIso8601String(),
  };

  static Map<String, Object?> _encodeCategory(Category category) => {
    'id': category.id,
    'name': category.name,
    'color': category.color,
  };

  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : throw const FormatException();

  static TimeRecord _decodeRecord(Object? value) {
    final map = _map(value);
    return TimeRecord(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String?,
      startTime: DateTime.parse(map['startTime'] as String).toUtc(),
      endTime: DateTime.parse(map['endTime'] as String).toUtc(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
    );
  }

  static Category _decodeCategory(Object? value) {
    final map = _map(value);
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
    );
  }

  static Map<String, Object?> _map(Object? value) => value is Map
      ? {for (final entry in value.entries) entry.key as String: entry.value}
      : throw const FormatException();
}

/// Immutable state required to restore an interrupted import.
class ImportRecovery {
  const ImportRecovery({
    required this.records,
    required this.categories,
    required this.syncSnapshot,
    required this.revision,
    required this.metadata,
    required this.pendingRevision,
  });

  final List<TimeRecord> records;
  final List<Category> categories;
  final String? syncSnapshot;
  final String? revision;
  final String? metadata;
  final String? pendingRevision;
}
