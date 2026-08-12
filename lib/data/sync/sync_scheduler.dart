import 'dart:io';

import 'package:workmanager/workmanager.dart';

/// Schedules a single deferred WebDAV synchronization.
abstract interface class SyncScheduler {
  Future<void> schedule();
}

/// Safe scheduler for platforms without background execution support.
class NoopSyncScheduler implements SyncScheduler {
  const NoopSyncScheduler();
  @override
  Future<void> schedule() async {}
}

/// Registers a network-constrained background synchronization.
///
/// Android schedules a WorkManager request. On iOS 13+ a BGProcessingTask is
/// scheduled instead of a one-off task (which only runs while the app is
/// transitioning to the background); its identifier must be declared in
/// `ios/Runner/Info.plist` under `BGTaskSchedulerPermittedIdentifiers` and
/// registered in `AppDelegate.swift` via
/// `WorkmanagerPlugin.registerBGProcessingTask`.
class WorkmanagerSyncScheduler implements SyncScheduler {
  static const taskName = 'mytime.webdav.sync';
  const WorkmanagerSyncScheduler();

  @override
  Future<void> schedule() {
    if (Platform.isAndroid) {
      return Workmanager().registerOneOffTask(
        taskName,
        taskName,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
    if (Platform.isIOS) {
      return Workmanager().registerProcessingTask(
        taskName,
        taskName,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
    return Future.value();
  }
}
