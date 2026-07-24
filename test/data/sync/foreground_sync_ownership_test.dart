import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';

void main() {
  test('treats a recent heartbeat as an active foreground owner', () async {
    final store = _MemoryPreferences();
    final ownership = ForegroundSyncOwnership(
      preferences: store,
      clock: () => DateTime.utc(2026, 7, 24, 9),
    );

    await ownership.activate();

    expect(await ownership.isForegroundActive(), isTrue);
  });

  test('treats a heartbeat older than 90 seconds as inactive', () async {
    final store = _MemoryPreferences()
      ..values['webdav.foreground.heartbeat'] = DateTime.utc(
        2026,
        7,
        24,
        8,
        58,
        29,
      ).toIso8601String();
    final ownership = ForegroundSyncOwnership(
      preferences: store,
      clock: () => DateTime.utc(2026, 7, 24, 9),
    );

    expect(await ownership.isForegroundActive(), isFalse);
  });

  test('removes its heartbeat when deactivated', () async {
    final store = _MemoryPreferences();
    final ownership = ForegroundSyncOwnership(preferences: store);
    await ownership.activate();

    await ownership.deactivate();

    expect(store.values['webdav.foreground.heartbeat'], isNull);
  });
}

class _MemoryPreferences implements PreferencesStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
