import 'package:mytime/data/sync/foreground_sync_ownership.dart';

/// Admits background WebDAV work only when the foreground is not synchronizing.
class WebDavBackgroundRunner {
  WebDavBackgroundRunner({
    required ForegroundSyncOwnership ownership,
    required Future<bool> Function() initializeAndSynchronize,
    Future<bool> Function()? foregroundIsActive,
  }) : _initializeAndSynchronize = initializeAndSynchronize,
       _foregroundIsActive = foregroundIsActive ?? ownership.isForegroundActive;

  final Future<bool> Function() _initializeAndSynchronize;
  final Future<bool> Function() _foregroundIsActive;

  Future<bool> run() async {
    if (await _foregroundIsActive()) return false;
    if (await _foregroundIsActive()) return false;
    return _initializeAndSynchronize();
  }
}
