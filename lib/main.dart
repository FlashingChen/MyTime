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
import 'package:mytime/data/sync/sync_execution_lock_port.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/webdav_background_task.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';
import 'package:mytime/ui/app_shell.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = SharedPreferencesStore();
  late final ForegroundSyncOwnership foregroundSyncOwnership;
  final (recordsBox, categoriesBox) = await initializeForegroundOwnedStorage(
    lock: const MethodChannelSyncExecutionLockPort(),
    activateForegroundOwnership: () async {
      foregroundSyncOwnership = await activateForegroundSyncOwnership(
        preferences,
      );
    },
    initializeHive: HiveHelper.init,
    initializeWorkmanager: () => Workmanager().initialize(callbackDispatcher),
    openBoxes: () async => (
      await HiveHelper.openRecordsBox(),
      await HiveHelper.openCategoriesBox(),
    ),
  );
  ForegroundSyncLifecycleOwner(foregroundSyncOwnership).start();
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
  final syncDataGate = SyncDataGate(
    lock: const MethodChannelSyncExecutionLockPort(),
  );

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

/// Activates the foreground ownership heartbeat before local storage opens.
Future<ForegroundSyncOwnership> activateForegroundSyncOwnership(
  PreferencesStore preferences,
) async {
  final ownership = ForegroundSyncOwnership(preferences: preferences);
  await ownership.activate();
  return ownership;
}

/// Activates foreground ownership before initializing local storage services.
Future<T> initializeForegroundOwnedStorage<T>({
  required SyncExecutionLockPort lock,
  required Future<void> Function() activateForegroundOwnership,
  required Future<void> Function() initializeHive,
  required Future<void> Function() initializeWorkmanager,
  required Future<T> Function() openBoxes,
}) async {
  await activateForegroundOwnership();
  await lock.acquire(timeoutMillis: 30000);
  try {
    await initializeHive();
    await initializeWorkmanager();
    return await openBoxes();
  } finally {
    await lock.release();
  }
}

/// Keeps the foreground sync ownership heartbeat aligned with app lifecycle.
class ForegroundSyncLifecycleOwner with WidgetsBindingObserver {
  ForegroundSyncLifecycleOwner(this._ownership);

  final ForegroundSyncOwnership _ownership;
  Timer? _refreshTimer;
  Future<void> _pendingOperation = Future.value();
  int _generation = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startRefreshTimer();
        _queueRefresh();
      case AppLifecycleState.inactive:
        _queueRefresh();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _refreshTimer?.cancel();
        _refreshTimer = null;
        _generation++;
        _queueOperation(_ownership.deactivate);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer ??= Timer.periodic(
      ForegroundSyncOwnership.refreshInterval,
      (_) => _queueRefresh(),
    );
  }

  void _queueRefresh() {
    final generation = _generation;
    _queueOperation(() async {
      if (generation == _generation) {
        await _ownership.refresh();
      }
    });
  }

  void _queueOperation(Future<void> Function() operation) {
    _pendingOperation = _pendingOperation
        .then<void>((_) => operation(), onError: (_, _) => operation())
        .catchError((_) {});
  }
}
