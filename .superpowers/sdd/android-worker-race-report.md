# Android Worker Reentrant Stop Race Report

## Root Cause

`SyncExecutionLockWorkRunner.stop()` marked the runner stopped, then waited while a delegate was being constructed or stopped. Both delegate callbacks execute outside `stateLock`. If either callback synchronously invoked `runner.stop()` on its own handoff thread, the nested call waited for the outer callback to finish, but the outer callback could not finish until the nested call returned.

## Regression Coverage

- `workerWrapperDefersReentrantStopDuringDelegateConstruction` invokes `runner.stop()` from `startDelegate` and requires `started`, `stopped`, then exactly one `released` event.
- `workerWrapperDefersReentrantStopDuringDelegateStopping` invokes `runner.stop()` from `stopDelegate` while its delegate future remains pending and requires the same ordered, single-release outcome.

The construction test failed before the production change at its one-second completion assertion, demonstrating the deadlock.

## Fix

The runner records the active delegate handoff thread while executing either callback. A `stop()` reentered by that same thread records the stop request and returns without waiting or releasing. The outer start/stop handoff observes the request, stops an admitted delegate when required, and retains the existing `releaseOnce()` guard.

## Verification

- Focused Dart WebDAV tests: passed, 19 tests.
- `flutter analyze`: passed, no issues.
- Android focused suite requires excluding `:integration_test:compileDebugJavaWithJavac` in this environment because `androidx.test:runner:1.2+` cannot be resolved: Google Maven TLS handshake fails online and no dynamic version metadata is cached offline.
