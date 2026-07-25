# Background Snapshot Sync Report

## Architecture

- Added `PreferencesSyncSnapshotStore`, which serializes a complete v2 `SyncSnapshot` (records, categories, revision, ETag, entity metadata, tombstones, and last-success timestamp) in `SharedPreferences`.
- WorkManager now checks the foreground heartbeat, then reads settings and only the persisted snapshot. It has no Hive imports, initialization, box access, repository construction, or Hive writes.
- Missing or malformed snapshots are removed and treated as no background work; the worker succeeds without opening Hive.
- Foreground startup retains persisted snapshot metadata and ETag but rebuilds entity payload from foreground Hive. Foreground mutations, imports, and foreground remote replacement refresh the snapshot under the shared foreground `SyncDataGate`.
- Removed the Android execution-lock application, WorkerFactory support, MethodChannel lock port, Android lock tests, manifest application configuration, and Dart native-lock integration. `SyncDataGate` is now an instance-local serialized queue with reentrant nested calls.

## Regression Coverage

- Snapshot v2 round trip includes ETag, entity metadata, and tombstones.
- Missing and malformed snapshots safely result in no work.
- Foreground reconciliation preserves metadata/ETag while replacing entity payload.
- Background snapshot synchronization persists the returned ETag.
- Worker runner only invokes the supplied snapshot synchronization path after an inactive heartbeat.
- Nested gate usage completes without a self-deadlock.

## Verification

- `dart format --set-exit-if-changed lib test`: passed, 0 files changed.
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 208 tests.
- `flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`.

## Scope Notes

- Existing dirty iOS files (`ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, and untracked `ios/Podfile`) were not modified or committed.
