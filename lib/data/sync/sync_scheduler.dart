import 'package:workmanager/workmanager.dart';

/// Schedules a single deferred WebDAV synchronization.
abstract interface class SyncScheduler {
  Future<void> schedule();
}

/// Safe scheduler for platforms without Android background execution.
class NoopSyncScheduler implements SyncScheduler {
  const NoopSyncScheduler();
  @override
  Future<void> schedule() async {}
}

/// Registers one network-constrained Android WorkManager request.
class WorkmanagerSyncScheduler implements SyncScheduler {
  static const taskName = 'mytime.webdav.sync';
  const WorkmanagerSyncScheduler();

  @override
  Future<void> schedule() => Workmanager().registerOneOffTask(
    taskName,
    taskName,
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
