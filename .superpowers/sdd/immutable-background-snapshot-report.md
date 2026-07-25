# Immutable Background Snapshot Report

## Root Cause

The WorkManager isolate passed `PreferencesSyncSnapshotStore` directly to
`WebDavSyncCoordinator` with local-result application enabled. `SyncService`
therefore called `replaceIfCurrent` after a successful conditional PUT. The
preferences implementation has no cross-isolate compare-and-swap, so a
foreground write between worker read and worker write could be replaced by the
worker's stale merged snapshot or stale ETag/success metadata.

## Fix

- Added `ReadOnlySyncLocalStore`, which delegates only read operations and
  refuses local replacement.
- The WorkManager path wraps its preferences snapshot store in that read-only
  view and invokes `WebDavSyncCoordinator` with `applyMergedLocal: false`.
- `PreferencesSyncSnapshotStore.readReadOnly` now decodes without malformed
  snapshot cleanup, so the worker never mutates preferences even on invalid
  input.
- The worker remains Hive-free and preserves GET/merge/conditional PUT,
  lock, and ETag retry behavior.

## Regression Coverage

`preferences_sync_snapshot_store_test.dart` pauses remote pull after the
worker reads its snapshot. The foreground writes a newer snapshot containing
an updated tombstone and ETag, then the worker completes its PUT. The test
asserts the exact persisted preferences bytes remain the foreground version,
the preferences write counter remains at the two foreground writes, and the
worker still performs one remote PUT. A following foreground sync pulls the
worker-updated remote document while retaining the newer local tombstone.

The regression failed before the fix because the worker replaced the
foreground ETag with its returned ETag and wrote a success timestamp.

## Verification

- `flutter test test/data/sync/preferences_sync_snapshot_store_test.dart test/data/sync/sync_service_test.dart test/data/sync/webdav_sync_coordinator_test.dart` passed: 12 tests.
- `flutter analyze` passed with no issues.
- `flutter test` passed: 208 tests.
- `flutter build apk --debug` passed and produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` passed.

## Scope

Unrelated dirty iOS files were not modified: `ios/Flutter/Debug.xcconfig`,
`ios/Flutter/Release.xcconfig`, and untracked `ios/Podfile`.
