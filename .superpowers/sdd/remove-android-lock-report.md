# Remove Obsolete Android Sync Lock Report

## Implementation

- Removed the obsolete Android sync execution-lock design and its two prior
  implementation reports.
- Removed lock-only Android WorkManager, Guava, concurrent-futures, and JUnit
  dependencies. The manifest and launcher activity use Flutter defaults; no
  custom application or WorkerFactory remains.
- Kept `SyncDataGate` as the per-instance future queue with Zone-based nested
  operation behavior. Added regression coverage that a failed operation does
  not block later queued work.
- Kept foreground ownership activation before Hive initialization. The worker
  continues to use only the immutable `PreferencesSyncSnapshotStore` snapshot;
  its runner accepts an injected snapshot-sync callback and has no Hive
  dependency.
- Revised architecture, README, and changelog documentation to identify Hive
  isolation and immutable background snapshots, rather than native locking, as
  the safety boundary.
- Retained the WebDAV XML `LOCK` content-type correction and all WebDAV lock
  protocol behavior.

## Verification

- `dart format --output=none --set-exit-if-changed lib test integration_test test_driver`
- `flutter analyze`
- `flutter test` (209 tests)
- `flutter build apk --debug`
- `git diff --check`

## Concerns

- The supplied worktree contained unrelated uncommitted iOS configuration
  files. They were left untouched and are not included in this commit.
