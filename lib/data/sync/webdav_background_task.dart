import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/preferences_sync_snapshot_store.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/webdav_background_runner.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';
import 'package:workmanager/workmanager.dart';

/// Registers the isolate-safe handler used by Android WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != WorkmanagerSyncScheduler.taskName) return true;
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final preferences = SharedPreferencesStore();
      final ownership = ForegroundSyncOwnership(preferences: preferences);
      return await WebDavBackgroundRunner(
        ownership: ownership,
        initializeAndSynchronize: () async {
          final settings = await SettingsRepository(
            preferences: preferences,
          ).load();
          if (!settings.hasWebDavConfiguration) return;
          final snapshotStore = PreferencesSyncSnapshotStore(preferences);
          try {
            await snapshotStore.readReadOnly();
          } on StateError {
            return;
          }
          if (await ownership.isForegroundActive()) return;
          await WebDavSyncCoordinator(
            local: ReadOnlySyncLocalStore(snapshotStore),
          ).synchronize(
            WebDavConfiguration(
              endpoint: settings.webDavEndpoint,
              username: settings.webDavUsername,
              password: settings.webDavPassword!,
            ),
            applyMergedLocal: false,
          );
        },
      ).run();
    } on FormatException {
      return true;
    } on ArgumentError {
      return true;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } catch (_) {
      return false;
    }
  });
}
