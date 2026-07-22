import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/sync_metadata.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';

void main() {
  test('persists entity revisions, tombstones, and the remote ETag', () async {
    final preferences = _Preferences();
    final store = PreferencesSyncMetadataStore(preferences);
    final changedAt = DateTime.utc(2026, 7, 22, 10);
    final deletedAt = DateTime.utc(2026, 7, 22, 12);

    await store.markChanged(SyncEntityKind.record, 'record-1', changedAt);
    await store.markDeleted(SyncEntityKind.record, 'record-1', deletedAt);
    await store.write((await store.read()).copyWith(eTag: '"etag-1"'));

    final metadata = await store.read();
    expect(metadata.records['record-1']!.updatedAt, changedAt);
    expect(metadata.records['record-1']!.deletedAt, deletedAt);
    expect(metadata.eTag, '"etag-1"');
  });

  test(
    'clears malformed metadata instead of failing application start',
    () async {
      final preferences = _Preferences()..values['sync_metadata'] = '{invalid';
      final store = PreferencesSyncMetadataStore(preferences);

      expect((await store.read()).records, isEmpty);
      expect(preferences.values, isEmpty);
    },
  );
}

class _Preferences implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
