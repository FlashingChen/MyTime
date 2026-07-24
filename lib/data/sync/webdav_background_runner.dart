import 'package:mytime/data/sync/foreground_sync_ownership.dart';

/// Admits background WebDAV work only when the foreground is not synchronizing.
class WebDavBackgroundRunner {
  WebDavBackgroundRunner({
    required ForegroundSyncOwnership ownership,
    required Future<void> Function() initializeAndSynchronize,
    Future<bool> Function()? foregroundIsActive,
  }) : _initializeAndSynchronize = initializeAndSynchronize,
       _foregroundIsActive = foregroundIsActive ?? ownership.isForegroundActive;

  final Future<void> Function() _initializeAndSynchronize;
  final Future<bool> Function() _foregroundIsActive;

  Future<bool> run() async {
    if (await _foregroundIsActive()) return true;
    if (await _foregroundIsActive()) return true;
    await _initializeAndSynchronize();
    return true;
  }
}
