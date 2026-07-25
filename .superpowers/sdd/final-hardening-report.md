# Final Hardening TDD Evidence

## Red

- `flutter test test/data/sync/revision_tracking_repositories_test.dart`
  failed the new gate regression before the production change: expected the
  snapshot-replaced record ID `replacement` to be marked, but the pre-gate
  selection marked stale ID `record`.
- `flutter test test/data/sync/webdav_sync_adapter_test.dart` failed the new
  malformed-token regression before the production change: `adapter.lock()`
  emitted `SyncLock` for `<>` instead of `FormatException`.

## Green

- Moved affected-record selection inside the same `SyncDataGate.run` operation
  as the bulk mutation and metadata marker calls.
- Rejected empty, partially bracketed, and angle-bracket-containing lock
  tokens unless they are a fully bracketed, non-empty token.
- Both focused suites pass after the changes. Final focused-test and analyzer
  command output is recorded in the task completion evidence.
