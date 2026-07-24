# Task 1 Report: Foreground Ownership Heartbeat

## Scope

Implemented Task 1 only: a SharedPreferences-backed foreground sync heartbeat
and the Flutter lifecycle observer that owns it.

## Files Changed

- `lib/data/sync/foreground_sync_ownership.dart`
  - Added `ForegroundSyncOwnership` backed by `PreferencesStore`.
  - Uses the required `webdav.foreground.heartbeat` UTC ISO-8601 value.
  - Uses the required 30-second refresh interval and 90-second active window.
  - Supports activation, refresh, deactivation, and foreground-active checks.
- `lib/main.dart`
  - Creates and activates one ownership instance at application startup.
  - Retains a `WidgetsBindingObserver` that starts a periodic heartbeat.
  - Refreshes on `resumed` and `inactive`.
  - Cancels the periodic heartbeat and removes ownership on `paused`, `hidden`,
    and `detached`.
- `test/data/sync/foreground_sync_ownership_test.dart`
  - Added the three specified unit tests for recent, stale, and deactivated
    heartbeats.

## TDD Evidence

1. Added the ownership tests before production code.
2. Ran `flutter test test/data/sync/foreground_sync_ownership_test.dart`.
3. Observed the expected compilation failure because
   `ForegroundSyncOwnership` and its source file did not yet exist.
4. Implemented the minimal ownership class and lifecycle integration.
5. Ran the focused test and analyzer after implementation.

## Verification

- `dart format lib/main.dart lib/data/sync/foreground_sync_ownership.dart test/data/sync/foreground_sync_ownership_test.dart`
  - Completed successfully.
- `flutter test test/data/sync/foreground_sync_ownership_test.dart && flutter analyze`
  - Focused test: 3 passed.
  - Analyzer: `No issues found!`
- `git diff --check`
  - Completed successfully during self-review.

## Self-Review

- Confirmed the heartbeat key, refresh interval, active window, UTC timestamp
  normalization, and lifecycle states match the binding Task 1 brief.
- Confirmed only the three required Task 1 source/test files were staged and
  committed.
- Confirmed unrelated existing iOS changes were not staged or modified.

## Commit

- `1dbd8f13946b53c0103d22f745c097a14864fad1 Add foreground sync ownership`

## Concerns

- None. The pre-existing modified `ios/Flutter/Debug.xcconfig`,
  `ios/Flutter/Release.xcconfig`, and untracked `ios/Podfile` remain outside
  this task's commit.

## Review Fixes

### Files Changed

- `lib/main.dart`
  - Serialized lifecycle refresh and deactivation operations with a generation
    guard, ensuring a pending refresh cannot recreate the heartbeat after a
    background lifecycle state removes it.
  - Exposed the small lifecycle owner for direct regression coverage.
- `lib/data/sync/foreground_sync_ownership.dart`
  - Rejects a heartbeat that is later than the current UTC clock.
- `test/data/sync/foreground_sync_ownership_test.dart`
  - Added regression coverage for a pending refresh/deactivate race and for a
    future-dated heartbeat.

### Verification

- `flutter test test/data/sync/foreground_sync_ownership_test.dart`
  - 5 tests passed.
- `flutter analyze`
  - `No issues found!`
- `git diff --check`
  - Completed successfully before committing.

### Commit

- `4343326 Fix foreground sync heartbeat races`

### Concerns

- The existing iOS changes remain unmodified and uncommitted. The lifecycle
  owner remains retained by `WidgetsBinding` after `start()`, as required for
  lifecycle observation.

## Reviewer Fix: Recover Lifecycle Operation Queue

### Root Cause

- `_pendingOperation` chained each lifecycle operation with `then`. A failed
  refresh left that future in an error state, causing later `then` callbacks,
  including deactivation, to be skipped. Its unawaited error was also exposed
  to the async error zone.

### Files Changed

- `lib/main.dart`
  - Recovers a prior failed queue operation before running the next operation.
  - Consumes the current operation failure so async lifecycle errors do not
    escape unhandled or poison future lifecycle work.
- `test/data/sync/foreground_sync_ownership_test.dart`
  - Added a failing-refresh preferences store regression test that verifies a
    later paused-state deactivation runs and removes the heartbeat.

### Verification

- `flutter test test/data/sync/foreground_sync_ownership_test.dart`
  - 6 tests passed, including the failed-refresh/deactivation regression.
- `flutter analyze`
  - `No issues found!`
- `git diff --check`
  - Completed successfully.

### Scope

- Unrelated iOS changes remain unmodified and unstaged.
