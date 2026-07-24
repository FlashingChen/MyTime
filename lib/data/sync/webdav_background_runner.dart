import 'package:mytime/data/sync/foreground_sync_ownership.dart';

/// Admits background WebDAV work only when the foreground is not synchronizing.
class WebDavBackgroundRunner {
  WebDavBackgroundRunner({
    required ForegroundSyncOwnership ownership,
    required Future<void> Function() initializeAndSynchronize,
  }) : _ownership = ownership,
       _initializeAndSynchronize = initializeAndSynchronize;

  final ForegroundSyncOwnership _ownership;
  final Future<void> Function() _initializeAndSynchronize;

  Future<bool> run() async {
    if (await _ownership.isForegroundActive()) return true;
    await _initializeAndSynchronize();
    return true;
  }
}
