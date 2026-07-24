import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/blocs/settings/settings.dart';
import 'package:mytime/blocs/timer/timer.dart';
import 'package:mytime/core/utils/hive_helper.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/providers/preferences_store.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/data/services/data_transfer_service.dart';
import 'package:mytime/data/sync/revision_tracking_repositories.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/webdav_background_task.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';
import 'package:mytime/ui/app_shell.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveHelper.init();
  await Workmanager().initialize(callbackDispatcher);

  final recordsBox = await HiveHelper.openRecordsBox();
  final categoriesBox = await HiveHelper.openCategoriesBox();
  final preferences = SharedPreferencesStore();
  final foregroundSyncOwnership = ForegroundSyncOwnership(
    preferences: preferences,
  );
  await foregroundSyncOwnership.activate();
  _ForegroundSyncLifecycleOwner(foregroundSyncOwnership).start();
  final rawRecordRepository = RecordRepository.withStore(
    HiveRecordDataStore(recordsBox),
  );
  final rawCategoryRepository = CategoryRepository.withStore(
    HiveCategoryDataStore(categoriesBox),
  );
  final revisionStore = PreferencesSyncRevisionStore(preferences);
  final metadataStore = PreferencesSyncMetadataStore(preferences);
  final mutationTracker = SyncMutationTracker(
    revision: revisionStore,
    metadata: metadataStore,
    scheduler: const WorkmanagerSyncScheduler(),
  );
  final syncDataGate = SyncDataGate();

  // User-originated writes use the decorators. Sync replacement deliberately
  // receives the raw repositories so a pulled remote revision remains remote.
  final recordRepo = RevisionTrackingRecordsRepository(
    delegate: rawRecordRepository,
    marker: mutationTracker,
    gate: syncDataGate,
  );
  final categoryRepo = RevisionTrackingCategoriesRepository(
    delegate: rawCategoryRepository,
    marker: mutationTracker,
    gate: syncDataGate,
  );
  final localSyncStore = RepositorySyncLocalStore(
    records: rawRecordRepository,
    categories: rawCategoryRepository,
    revision: revisionStore,
    metadata: metadataStore,
    gate: syncDataGate,
  );
  final settingsRepo = SettingsRepository(preferences: preferences);
  final activeTimerRepo = ActiveTimerRepository(preferences: preferences);
  final dataTransferService = DataTransferService(
    rawRecordRepository,
    rawCategoryRepository,
    mutationMarker: mutationTracker,
    gate: syncDataGate,
  );
  final webDavSyncCoordinator = WebDavSyncCoordinator(local: localSyncStore);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SyncLocalStore>.value(value: localSyncStore),
        RepositoryProvider.value(value: webDavSyncCoordinator),
        RepositoryProvider.value(value: dataTransferService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => TimerBloc(activeTimerRepo)..add(RestoreTimer()),
          ),
          BlocProvider(
            create: (_) => RecordsBloc(recordRepo)..add(LoadRecords()),
          ),
          BlocProvider(
            create: (_) =>
                CategoriesBloc(categoryRepo, recordRepo)..add(LoadCategories()),
          ),
          BlocProvider(
            create: (_) => SettingsBloc(settingsRepo)..add(LoadSettings()),
          ),
        ],
        child: const AppShell(),
      ),
    ),
  );
}

class _ForegroundSyncLifecycleOwner with WidgetsBindingObserver {
  _ForegroundSyncLifecycleOwner(this._ownership);

  final ForegroundSyncOwnership _ownership;
  Timer? _refreshTimer;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startRefreshTimer();
        unawaited(_ownership.refresh());
      case AppLifecycleState.inactive:
        unawaited(_ownership.refresh());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _refreshTimer?.cancel();
        _refreshTimer = null;
        unawaited(_ownership.deactivate());
    }
  }

  void _startRefreshTimer() {
    _refreshTimer ??= Timer.periodic(
      ForegroundSyncOwnership.refreshInterval,
      (_) => unawaited(_ownership.refresh()),
    );
  }
}
