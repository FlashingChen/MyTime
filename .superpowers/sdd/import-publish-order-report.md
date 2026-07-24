# Import Publish Order Report

## Scope

Resolved all three import rollback findings without changing the Android worker
or any iOS file.

## Root Cause

`SyncMutationTracker.markImportedChanges` scheduled WorkManager before it
published the refreshed background snapshot. On a publication failure, a worker
could observe and upload imported Hive data or stale/new sync state before the
transaction rolled back. `DataTransferService` then tried to reconstruct the
old snapshot using another refresh after restoring Hive, which was itself a
fallible operation. Non-entity mutation markers returned before publishing a
snapshot.

## Change

- The import tracker now persists revision and metadata, publishes the
  background snapshot, and only then makes the best-effort WorkManager
  scheduling request.
- `DataTransferService` captures the exact serialized background snapshot
  before entity writes. On any import failure it restores Hive entities and the
  captured value directly, rather than performing a compensating refresh.
- `PreferencesSyncSnapshotStore` exposes internal capture/restore operations
  for that exact serialized value; it does not involve Hive.
- Imports using no entity marker or only `SyncMutationMarker` now refresh the
  background snapshot after the marker completes.

## Regression Coverage

- A successful imported mutation records `snapshot` before `schedule`.
- A publication failure that writes a new value before throwing leaves the old
  captured snapshot, prior revision, metadata, records, and categories in
  place, with zero scheduling attempts. This path has no compensating refresh
  to fail.
- An import using a non-entity marker performs exactly one background snapshot
  refresh.
- Regression sensitivity was confirmed by temporarily restoring the unsafe
  ordering and early return: all three new tests failed for their intended
  assertions.

## Verification

- `flutter test test/data/services/data_transfer_service_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
