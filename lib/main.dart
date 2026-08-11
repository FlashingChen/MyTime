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
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/active_timer_repository.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/data/services/data_transfer_service.dart';
import 'package:mytime/data/services/import_recovery_journal.dart';
import 'package:mytime/data/services/timer_notification_service.dart';
import 'package:mytime/data/services/timer_reminder_scheduler.dart';
import 'package:mytime/data/sync/revision_tracking_repositories.dart';
import 'package:mytime/data/sync/foreground_sync_ownership.dart';
import 'package:mytime/data/sync/foreground_sync_mutation_dispatcher.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_mutation_tracker.dart';
import 'package:mytime/data/sync/sync_data_gate.dart';
import 'package:mytime/data/sync/preferences_sync_snapshot_store.dart';
import 'package:mytime/data/sync/sync_revision_store.dart';
import 'package:mytime/data/sync/sync_metadata_store.dart';
import 'package:mytime/data/sync/sync_scheduler.dart';
import 'package:mytime/data/sync/sync_pending_state_store.dart';
import 'package:mytime/data/sync/webdav_background_task.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';
import 'package:mytime/ui/app_shell.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = SharedPreferencesStore();
  late final ForegroundSyncOwnership foregroundSyncOwnership;
  foregroundSyncOwnership = await activateForegroundSyncOwnership(preferences);
  await HiveHelper.init();
  final (recordsBox, categoriesBox) = (
    await HiveHelper.openRecordsBox(),
    await HiveHelper.openCategoriesBox(),
  );
  final rawRecordRepository = RecordRepository.withStore(
    HiveRecordDataStore(recordsBox),
  );
  final rawCategoryRepository = CategoryRepository.withStore(
    HiveCategoryDataStore(categoriesBox),
  );
  final revisionStore = PreferencesSyncRevisionStore(preferences);
  final metadataStore = PreferencesSyncMetadataStore(preferences);
  final snapshotStore = PreferencesSyncSnapshotStore(preferences);
  final pendingStore = PreferencesSyncPendingStateStore(preferences);
  final importRecoveryJournal = ImportRecoveryJournal(preferences);
  final syncDataGate = SyncDataGate();
  late final RepositorySyncLocalStore localSyncStore;
  Future<void> refreshSnapshot() => syncDataGate.run(() async {
    await snapshotStore.write(await localSyncStore.readReadOnly());
  });
  localSyncStore = RepositorySyncLocalStore(
    records: rawRecordRepository,
    categories: rawCategoryRepository,
    revision: revisionStore,
    metadata: metadataStore,
    gate: syncDataGate,
    refreshSnapshot: refreshSnapshot,
  );
  final settingsRepo = SettingsRepository(preferences: preferences);
  await DataTransferService.recoverPendingImport(
    rawRecordRepository,
    rawCategoryRepository,
    importRecoveryJournal,
  );
  await Workmanager().initialize(callbackDispatcher);
  final webDavSyncCoordinator = WebDavSyncCoordinator(local: localSyncStore);
  final foregroundMutationDispatcher = ForegroundSyncMutationDispatcher(
    foregroundIsActive: foregroundSyncOwnership.isForegroundActive,
    synchronize: () => synchronizeWebDavOnStartup(
      loadSettings: settingsRepo.load,
      synchronize: webDavSyncCoordinator.synchronize,
    ),
    scheduler: const WorkmanagerSyncScheduler(),
    pending: pendingStore,
  );
  ForegroundSyncLifecycleOwner(
    foregroundSyncOwnership,
    onForegroundActive: foregroundMutationDispatcher.foregroundBecameActive,
    onForegroundInactive: foregroundMutationDispatcher.foregroundBecameInactive,
  ).start();
  final mutationTracker = SyncMutationTracker(
    revision: revisionStore,
    metadata: metadataStore,
    foregroundDispatcher: foregroundMutationDispatcher,
    refreshSnapshot: refreshSnapshot,
    pending: pendingStore,
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
  final activeTimerRepo = ActiveTimerRepository(preferences: preferences);
  final timerNotificationService = LocalNotificationsService();
  final reminderScheduler = TimerReminderScheduler(timerNotificationService);
  await timerNotificationService.initialize();
  final dataTransferService = DataTransferService(
    rawRecordRepository,
    rawCategoryRepository,
    mutationMarker: mutationTracker,
    gate: syncDataGate,
    refreshSnapshot: refreshSnapshot,
    captureSnapshot: snapshotStore.captureSerialized,
    restoreSnapshot: snapshotStore.restoreSerialized,
    recoveryJournal: importRecoveryJournal,
  );
  await syncDataGate.run(() async {
    final reconciled = await snapshotStore.reconcileForeground(
      await localSyncStore.readReadOnly(),
    );
    await metadataStore.write(reconciled.metadata);
  });
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
            create: (_) =>
                TimerBloc(activeTimerRepo, reminderScheduler: reminderScheduler)
                  ..add(RestoreTimer()),
          ),
          BlocProvider(
            create: (_) => RecordsBloc(recordRepo)..add(LoadRecords()),
          ),
          BlocProvider(
            create: (_) =>
                CategoriesBloc(categoryRepo, recordRepo)..add(LoadCategories()),
          ),
          BlocProvider(
            create: (_) => SettingsBloc(
              settingsRepo,
              onSettingsChanged: reminderScheduler.configure,
            )..add(LoadSettings()),
          ),
        ],
        child: const AppShell(),
      ),
    ),
  );
  unawaited(
    synchronizeWebDavOnStartup(
      loadSettings: settingsRepo.load,
      synchronize: webDavSyncCoordinator.synchronize,
      pending: pendingStore,
      scheduler: const WorkmanagerSyncScheduler(),
    ).catchError((Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }),
  );
}

/// Pulls remote changes through the foreground coordinator after startup.
Future<void> synchronizeWebDavOnStartup({
  required Future<AppSettings> Function() loadSettings,
  required Future<Object?> Function(WebDavConfiguration configuration)
  synchronize,
  Future<void> Function()? recoverPendingImport,
  SyncPendingStateStore? pending,
  SyncScheduler? scheduler,
}) async {
  try {
    await recoverPendingImport?.call();
    final settings = await loadSettings();
    if (!settings.hasWebDavConfiguration) return;
    final attempt = await pending?.readPendingRevision();
    await synchronize(
      WebDavConfiguration.fromServer(
        server: settings.webDavEndpoint,
        username: settings.webDavUsername,
        password: settings.webDavPassword!,
      ),
    );
    if (attempt != null) await pending!.clearIfMatches(attempt);
  } catch (error, stackTrace) {
    if (pending != null) {
      try {
        await scheduler?.schedule();
      } catch (_) {}
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
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
  required Future<void> Function() activateForegroundOwnership,
  required Future<void> Function() initializeHive,
  required Future<void> Function() initializeWorkmanager,
  required Future<T> Function() openBoxes,
}) async {
  await activateForegroundOwnership();
  await initializeHive();
  await initializeWorkmanager();
  return openBoxes();
}

/// Keeps the foreground sync ownership heartbeat aligned with app lifecycle.
class ForegroundSyncLifecycleOwner with WidgetsBindingObserver {
  ForegroundSyncLifecycleOwner(
    this._ownership, {
    FutureOr<void> Function()? onForegroundActive,
    FutureOr<void> Function()? onForegroundInactive,
  }) : _onForegroundActive = onForegroundActive,
       _onForegroundInactive = onForegroundInactive;

  final ForegroundSyncOwnership _ownership;
  final FutureOr<void> Function()? _onForegroundActive;
  final FutureOr<void> Function()? _onForegroundInactive;
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
        _generation++;
        _startRefreshTimer();
        _queueForegroundActivation();
      case AppLifecycleState.inactive:
        _queueRefresh();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _refreshTimer?.cancel();
        _refreshTimer = null;
        _generation++;
        final generation = _generation;
        _queueOperation(() async {
          if (generation != _generation) return;
          await _ownership.deactivate();
          if (generation != _generation) return;
          await _onForegroundInactive?.call();
        });
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

  void _queueForegroundActivation() {
    final generation = _generation;
    _queueOperation(() async {
      if (generation != _generation) return;
      await _ownership.refresh();
      if (generation != _generation) return;
      await _onForegroundActive?.call();
    });
  }

  void _queueOperation(Future<void> Function() operation) {
    _pendingOperation = _pendingOperation
        .then<void>((_) => operation(), onError: (_, _) => operation())
        .catchError((_) {});
  }
}
