# Android Sync Execution Lock Design

## Goal

Provide one Android-process lock that prevents the foreground Flutter engine
and the WorkManager Flutter engine from accessing MyTime's Hive data or
running synchronization concurrently.

The existing SharedPreferences foreground heartbeat remains an optimization:
an active foreground app makes WorkManager skip before Hive setup. The native
lock is the correctness boundary for startup, lifecycle, and heartbeat races.

## Native Lock

`SyncExecutionLock` is an Android Kotlin singleton using one fair
`ReentrantLock` in the default application process.

It exposes a Flutter `MethodChannel` with:

- `acquireSyncLock`, accepting `timeoutMillis` and returning `true` only after
  ownership is acquired.
- `releaseSyncLock`, releasing the current holder's lock.

The project does not configure WorkManager to run in a separate Android
process. The foreground Activity and the WorkManager callback therefore share
this singleton. No additional dependency is required.

## Dart Gate

`SyncDataGate` retains its per-instance future queue and wraps each queued
operation in the native lock:

- Foreground callers use no acquisition timeout and wait until the lock is
  available. This protects record/category mutations, imports, and foreground
  sync snapshot replacement.
- The gate always releases the native lock in `finally`, including when its
  operation throws.
- Test implementations can inject a lock port; non-Android test environments
  use an in-memory port with equivalent ownership semantics.

The gate must not claim cross-process behavior. It is an Android default-process
coordination primitive only.

## WorkManager Flow

The callback retains its foreground-heartbeat admission check before Hive
initialization. If the heartbeat is active, it completes successfully without
opening Hive.

If there is no fresh heartbeat:

1. Attempt the native lock with a 30-second timeout before `HiveHelper.init()`.
2. If the timeout expires, return `false` so WorkManager retries later; do not
   open Hive or create repositories.
3. Once acquired, initialize Hive, create the background repository graph,
   read raw non-mutating records/categories, and conditionally synchronize.
4. Keep `applyMergedLocal: false`; the worker never applies a merged Hive
   snapshot.
5. Release the native lock in `finally` before returning the WorkManager
   outcome.

This handles races where the worker starts just before foreground heartbeat
activation, and where a foreground lifecycle transition clears the heartbeat
while foreground Hive boxes remain open.

## WebDAV Lock Request

The optional WebDAV `LOCK` request uses
`Content-Type: application/xml; charset=utf-8`; JSON remains the content type
for WebDAV document GET/PUT requests.

WebDAV protocol behavior remains unchanged:

- `405` and `501` mean LOCK is unsupported and synchronization falls back to
  ETag-only conditional PUT.
- `423 Locked` remains lock contention and fails the attempt without PUT.
- Normalized lock tokens are valid coded URLs: PUT uses
  `If: (<opaquelocktoken:...>)` and UNLOCK uses
  `Lock-Token: <opaquelocktoken:...>`.

## Merge Policy

Same-ID entity conflicts remain local-wins. Entity timestamps do not override
the confirmed local-wins policy. Valid tombstones prevent entity resurrection
for 90 days.

## Tests

Add tests for:

- The Dart gate acquires and releases the injected native lock around both
  success and failure paths.
- A WorkManager attempt with an active heartbeat does not acquire the lock or
  initialize Hive.
- A worker lock timeout returns retry (`false`) before Hive setup.
- A worker acquired lock is released after success and after an error.
- Foreground mutations wait for the lock port while worker ownership is held.
- Android unit tests prove `SyncExecutionLock` serializes two callers and
  releases after a thrown block.
- WebDAV LOCK uses XML content type while PUT retains JSON content type.

Run `dart format --output=none --set-exit-if-changed lib test integration_test
test_driver`, `flutter analyze`, `flutter test`, Android unit tests, and
`flutter build apk --debug`.
