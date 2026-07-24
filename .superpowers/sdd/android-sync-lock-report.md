# Android Sync Execution Lock Report

## Implementation

- Added `SyncExecutionLock`, a fair Android process-wide `Semaphore(1, true)`
  with atomic foreground activity tracking.
- Added `MyTimeApplication` and a custom WorkManager `WorkerFactory` that
  acquires before constructing workmanager's `BackgroundWorker` and releases
  once on completion or stop.
- Added foreground MethodChannel and Dart lock port/gate integration; the
  background callback bypasses Dart re-acquisition because the wrapper owns
  the native semaphore.
- Corrected WebDAV LOCK content type to `application/xml; charset=utf-8`.

## Tests

- PASS: `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/foreground_sync_ownership_test.dart test/data/sync/webdav_sync_adapter_test.dart`
- PASS: `flutter analyze`
- PASS: `flutter test` (206 tests)
- PASS: `flutter build apk --debug` (`build/app/outputs/flutter-apk/app-debug.apk`)
- PASS: `cd android && ./gradlew :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest`
- PASS: `dart format --output=none --set-exit-if-changed lib test integration_test test_driver`

## Commits

- `Add Android sync execution lock`

## Concerns

- `./gradlew testDebugUnitTest --tests ...` applies its class filter to
  transitive plugin test tasks and fails when those tasks have no matching
  class. The app-scoped command above is the successful equivalent.
