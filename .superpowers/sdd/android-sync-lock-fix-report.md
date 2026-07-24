# Android Sync Execution Lock Fix Report

## Root Cause

- Foreground Dart paths supplied a finite 30,000ms timeout, so foreground
  storage startup and `SyncDataGate` could fail instead of waiting for the
  native owner.
- The Android lock tracked ownership with one shared boolean. A delayed former
  holder could therefore release a newer holder's semaphore permit.
- The worker created `BackgroundWorker` after its timed acquisition without
  atomically rechecking stop and foreground state.

## Fix

- `SyncExecutionLock.acquire` now returns a UUID token, accepts `null` for an
  indefinite wait, and releases only the matching current token.
- Dart acquire returns that token and Dart gates release it in `finally`.
  Foreground startup and foreground data gates omit `timeoutMillis`; only the
  WorkerFactory wrapper passes 30,000ms.
- `SyncExecutionLockWorkRunner` atomically owns stopped/acquired/released state
  around delegate admission. It rechecks foreground attachment after acquiring,
  releases on both retry paths, and never creates the delegate in either path.
- Worker behavior is covered with injected acquisition/delegate functions,
  preserving the workmanager 0.9 `BackgroundWorker` production constructor.

## Red Evidence

- `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/foreground_sync_ownership_test.dart`
  initially failed at the intended port interface boundary: test locks returned
  tokens and required release tokens, while `SyncExecutionLockPort` still used
  `Future<void> acquire({required int timeoutMillis})` and `release()`.
- `cd android && ./gradlew :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest`
  initially reached Kotlin test compilation and failed because the new tests
  incorrectly expected nonexistent `Result.retry` and `Result.success`
  properties. The production Android sources compiled before that test error.

## Green Evidence

- PASS: `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/foreground_sync_ownership_test.dart` (13 tests)
- PASS: `flutter analyze` (`No issues found!`)
- PASS: `flutter test` (207 tests)

## Android Unit Test Constraint

- Attempted: `cd android && ./gradlew :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest`
- Attempted offline: `cd android && ./gradlew --offline :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest`
- Both final attempts stop before app unit test execution because the transitive
  `:integration_test` project requires dynamic dependency
  `androidx.test:runner:1.2+`. Online resolution fails TLS handshake while
  fetching Maven metadata; offline mode has no cached version listing. This is
  an external dependency-resolution constraint, not an Android source/test
  failure.
