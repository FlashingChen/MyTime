import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_port.dart';
import 'package:mytime/data/sync/sync_service.dart';
import 'package:mytime/data/sync/webdav_sync_adapter.dart';

/// Credentials and document location required for one WebDAV synchronization.
class WebDavConfiguration {
  const WebDavConfiguration({
    required this.endpoint,
    required this.username,
    required this.password,
  });

  final String endpoint;
  final String username;
  final String password;
}

/// Factory seam for testing the WebDAV transport without a network request.
typedef WebDavPortFactory =
    SyncPort Function(WebDavConfiguration configuration);

/// Builds a WebDAV adapter from saved settings and runs a serialized sync.
class WebDavSyncCoordinator {
  WebDavSyncCoordinator({
    required SyncLocalStore local,
    WebDavPortFactory? portFactory,
  }) : _local = local,
       _portFactory = portFactory ?? _defaultPort;

  final SyncLocalStore _local;
  final WebDavPortFactory _portFactory;
  Future<SyncResult>? _inFlight;

  /// Synchronizes the current local snapshot with [configuration]'s document.
  Future<SyncResult> synchronize(
    WebDavConfiguration configuration, {
    bool applyMergedLocal = true,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final attempt = SyncService(
      local: _local,
      remote: _portFactory(configuration),
      applyMergedLocal: applyMergedLocal,
    ).synchronize();
    _inFlight = attempt;
    attempt.then<void>(
      (_) => _clearInFlight(attempt),
      onError: (Object _, StackTrace __) => _clearInFlight(attempt),
    );
    return attempt;
  }

  static SyncPort _defaultPort(WebDavConfiguration configuration) {
    return WebDavSyncAdapter(
      endpoint: Uri.parse(configuration.endpoint),
      username: configuration.username,
      password: configuration.password,
    );
  }

  void _clearInFlight(Future<SyncResult> completed) {
    if (identical(_inFlight, completed)) _inFlight = null;
  }
}
