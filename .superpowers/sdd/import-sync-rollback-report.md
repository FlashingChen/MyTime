# Import Sync Rollback Report

## Scope

Fixed the failed backup-import path so a refresh failure cannot leave a newer
sync revision, changed entity metadata, tombstones, or a background snapshot
after Hive entities are restored.

## Root Cause

`DataTransferService` marked every imported entity separately. Each marker call
advanced the revision, persisted metadata, and refreshed the background
snapshot before the next call. The service rollback restored only Hive data.

## Change

`SyncMutationTracker` now supports a batched import mutation. It captures the
previous revision and metadata, persists all import entity changes in one write,
and restores both if snapshot refresh fails. `DataTransferService` uses that
transactional path when available, restores Hive data after an error, and then
refreshes the restored background snapshot. Existing marker implementations
retain their prior behavior.

## Regression Coverage

The deterministic data-transfer test uses the real `SyncMutationTracker` with
in-memory revision and metadata stores. Its first snapshot refresh changes the
snapshot then throws. The test asserts the import error leaves the old Hive
records/categories, revision, entity metadata, and background snapshot in
place after the rollback refresh.

## Verification

- `flutter test test/data/services/data_transfer_service_test.dart`
- `flutter analyze`
