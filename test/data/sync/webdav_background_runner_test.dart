import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/webdav_background_runner.dart';

void main() {
  test('worker skip returns before the configured sync callback', () async {
    var synchronized = false;
    final runner = WebDavBackgroundRunner(
      ownership: _ActiveOwnership(true),
      initializeAndSynchronize: () async => synchronized = true,
    );

    expect(await runner.run(), isTrue);
    expect(synchronized, isFalse);
  });

  test('runs snapshot sync when no foreground owner is active', () async {
    var synchronized = false;
    final runner = WebDavBackgroundRunner(
      ownership: _ActiveOwnership(false),
      initializeAndSynchronize: () async => synchronized = true,
    );

    expect(await runner.run(), isTrue);
    expect(synchronized, isTrue);
  });
}

class _ActiveOwnership extends ForegroundSyncOwnership {
  _ActiveOwnership(this._active) : super(preferences: _UnusedPreferences());

  final bool _active;

  @override
  Future<bool> isForegroundActive() async => _active;
}

class _UnusedPreferences implements PreferencesStore {
  @override
  Future<String?> getString(String key) => throw UnimplementedError();

  @override
  Future<void> remove(String key) => throw UnimplementedError();

  @override
  Future<void> setString(String key, String value) =>
      throw UnimplementedError();
}
