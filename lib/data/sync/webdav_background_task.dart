import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mytime/core/utils/hive_helper.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
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
      return await WebDavBackgroundRunner(
        ownership: ForegroundSyncOwnership(preferences: preferences),
        initializeAndSynchronize: () async {
          await HiveHelper.init();
          final settings = await SettingsRepository(
            preferences: preferences,
          ).load();
          if (!settings.hasWebDavConfiguration) return;
          final recordStore = HiveRecordDataStore(
            await HiveHelper.openRecordsBox(),
          );
          final categoryStore = HiveCategoryDataStore(
            await HiveHelper.openCategoriesBox(),
          );
          final records = RecordRepository.withStore(recordStore);
          final categories = CategoryRepository.withStore(categoryStore);
          final local = RepositorySyncLocalStore(
            records: records,
            categories: categories,
            revision: PreferencesSyncRevisionStore(preferences),
            metadata: PreferencesSyncMetadataStore(preferences),
            gate: SyncDataGate(),
            readOnlyRecords: () async => recordStore.values.toList(),
            readOnlyCategories: () async => categoryStore.values.toList(),
          );
          await WebDavSyncCoordinator(local: local).synchronize(
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
