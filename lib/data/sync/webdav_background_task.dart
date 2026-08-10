import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/data/services/import_recovery_journal.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/preferences_sync_snapshot_store.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_merge_service.dart';
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
        initializeAndSynchronize: WebDavBackgroundTask.fromPreferences(
          preferences: preferences,
          foregroundIsActive: ownership.isForegroundActive,
        ).run,
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

/// Performs the Hive-free background WebDAV sequence after worker admission.
class WebDavBackgroundTask {
  WebDavBackgroundTask({
    required Future<bool> Function() hasPendingRecovery,
    required Future<AppSettings> Function() loadSettings,
    required Future<void> Function() readSnapshot,
    required Future<void> Function(AppSettings settings) synchronize,
    Future<bool> Function()? foregroundIsActive,
  }) : _hasPendingRecovery = hasPendingRecovery,
       _loadSettings = loadSettings,
       _readSnapshot = readSnapshot,
       _synchronize = synchronize,
       _foregroundIsActive = foregroundIsActive;

  factory WebDavBackgroundTask.fromPreferences({
    required PreferencesStore preferences,
    required Future<bool> Function() foregroundIsActive,
  }) {
    final snapshotStore = PreferencesSyncSnapshotStore(preferences);
    return WebDavBackgroundTask(
      hasPendingRecovery: ImportRecoveryJournal(preferences).hasPendingRecovery,
      loadSettings: () => SettingsRepository(preferences: preferences).load(),
      readSnapshot: snapshotStore.readReadOnly,
      foregroundIsActive: foregroundIsActive,
      synchronize: (settings) =>
          WebDavSyncCoordinator(
            local: ReadOnlySyncLocalStore(snapshotStore),
          ).synchronize(
            WebDavConfiguration.fromServer(
              server: settings.webDavEndpoint,
              username: settings.webDavUsername,
              password: settings.webDavPassword!,
            ),
            applyMergedLocal: false,
            conflictPolicy: SyncConflictPolicy.preferRemote,
          ),
    );
  }

  final Future<bool> Function() _hasPendingRecovery;
  final Future<AppSettings> Function() _loadSettings;
  final Future<void> Function() _readSnapshot;
  final Future<void> Function(AppSettings settings) _synchronize;
  final Future<bool> Function()? _foregroundIsActive;

  Future<bool> run() async {
    if (await _hasPendingRecovery()) return true;
    final settings = await _loadSettings();
    if (!settings.hasWebDavConfiguration) return true;
    try {
      await _readSnapshot();
    } on StateError {
      return true;
    }
    if (await _foregroundIsActive?.call() ?? false) return false;
    await _synchronize(settings);
    return true;
  }
}
