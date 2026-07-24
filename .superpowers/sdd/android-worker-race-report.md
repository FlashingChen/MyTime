# Android Worker Stop Race Report

## Root Cause

`SyncExecutionLockWorkRunner.start()` checked `stopped` under `stateLock` and
then constructed and started the Flutter `BackgroundWorker` while still in that
admission block. `stop()` used a separate atomic flag and released the token
immediately. A stop could therefore set its request after admission but before
delegate construction, release the native token, and allow Flutter work to
start afterward.

## Fix

- Admission records `startingDelegate` under `stateLock`; delegate construction
  and startup happen outside the lock so Flutter callbacks cannot reenter the
  state monitor.
- `stop()` synchronously waits for the handoff. If stop wins before admission,
  no delegate is constructed and the acquired token is released once. If start
  wins, stop dispatches `delegate.onStopped()` outside the lock and releases
  only after that callback returns.
- Completion, acquisition failure, retry, and delegate-stop paths share the
  same token release guard. A token is never released while an admitted,
  non-stopped delegate can run.

## Red Evidence

- Added `workerWrapperStopsDelegateBeforeReleasingWhenStoppedDuringDelegateConstruction`.
  It blocks injected delegate construction after safe admission, requests stop,
  then unblocks construction deterministically.
- Before the fix:
  `cd android && ./gradlew :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest.workerWrapperDoesNotConstructDelegateWhenStoppedAfterAdmission`
  failed at `SyncExecutionLockTest.kt:163`: the old runner constructed the
  delegate after the stop request was observable. The finalized regression
  asserts the legal start-wins behavior instead: `started`, then synchronous
  `stopped`, then `released`.

## Green Evidence

- PASS: `cd android && ./gradlew :app:testDebugUnitTest --tests com.mytime.mytime.SyncExecutionLockTest`
  (10 tests).
- PASS: `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/foreground_sync_ownership_test.dart`
  (13 tests).
- PASS: `flutter test` (207 tests).
- PASS: `flutter analyze` (`No issues found!`).

## Android Unit Test Constraint

- The focused `SyncExecutionLockTest` task executed successfully.
- Attempted full task: `cd android && ./gradlew :app:testDebugUnitTest`.
- The full task stops before app unit-test execution because `:integration_test`
  resolves dynamic dependency `androidx.test:runner:1.2+`; Maven metadata fetch
  from `https://dl.google.com/dl/android/maven2/androidx/test/runner/maven-metadata.xml`
  fails when the remote host terminates the TLS handshake. This is an external
  dependency-resolution blocker, not an Android source or focused test failure.
