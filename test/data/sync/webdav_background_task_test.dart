import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/services/import_recovery_journal.dart';
import 'package:mytime/data/sync/webdav_background_task.dart';

void main() {
  test('pending recovery checks only the journal', () async {
    final calls = <String>[];
    final task = WebDavBackgroundTask(
      hasPendingRecovery: () async {
        calls.add('journal');
        return true;
      },
      loadSettings: () async {
        calls.add('settings');
        return _configuredSettings;
      },
      readSnapshot: () async => calls.add('snapshot'),
      synchronize: (_) async => calls.add('sync'),
    );

    await task.run();

    expect(calls, ['journal']);
  });

  test(
    'runs configuration, snapshot, and sync after recovery admission',
    () async {
      final calls = <String>[];
      final task = WebDavBackgroundTask(
        hasPendingRecovery: () async {
          calls.add('journal');
          return false;
        },
        loadSettings: () async {
          calls.add('settings');
          return _configuredSettings;
        },
        readSnapshot: () async => calls.add('snapshot'),
        synchronize: (_) async => calls.add('sync'),
      );

      await task.run();

      expect(calls, ['journal', 'settings', 'snapshot', 'sync']);
    },
  );

  test('does not read the snapshot without WebDAV configuration', () async {
    final calls = <String>[];
    final task = WebDavBackgroundTask(
      hasPendingRecovery: () async {
        calls.add('journal');
        return false;
      },
      loadSettings: () async {
        calls.add('settings');
        return const AppSettings();
      },
      readSnapshot: () async => calls.add('snapshot'),
      synchronize: (_) async => calls.add('sync'),
    );

    await task.run();

    expect(calls, ['journal', 'settings']);
  });

  test(
    'returns retry when foreground activates after the snapshot read',
    () async {
      final task = WebDavBackgroundTask(
        hasPendingRecovery: () async => false,
        loadSettings: () async => _configuredSettings,
        readSnapshot: () async {},
        foregroundIsActive: () async => true,
        synchronize: (_) async => fail('must not synchronize'),
      );

      expect(await task.run(), isFalse);
    },
  );

  test(
    'invalid recovery journal fails before later worker operations',
    () async {
      final calls = <String>[];
      final preferences = _MemoryPreferences({
        ImportRecoveryJournal.key: '{bad',
      });
      final task = WebDavBackgroundTask(
        hasPendingRecovery: () async {
          calls.add('journal');
          return ImportRecoveryJournal(preferences).hasPendingRecovery();
        },
        loadSettings: () async {
          calls.add('settings');
          return _configuredSettings;
        },
        readSnapshot: () async => calls.add('snapshot'),
        synchronize: (_) async => calls.add('sync'),
      );

      await expectLater(task.run(), throwsStateError);

      expect(calls, ['journal']);
    },
  );
}

const _configuredSettings = AppSettings(
  webDavEndpoint: 'https://dav.example.com/mytime.json',
  webDavUsername: 'alice',
  webDavPassword: 'secret',
);

class _MemoryPreferences implements PreferencesStore {
  _MemoryPreferences(this.values);

  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}
