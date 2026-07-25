# Foreground Mutation Sync Report

## Root Cause

`SyncMutationTracker` persisted a local revision and metadata, then only
replaced the WorkManager request. While foreground ownership was active, the
worker correctly exited before its immutable, Hive-free remote-wins operation.
Replacing that skipped request left no foreground synchronization attempt, so a
local edit could remain pending until a later trigger.

## Fix

`ForegroundSyncMutationDispatcher` is composed in `main.dart`, outside the
storage-level mutation tracker. After a committed mutation and snapshot
publication, the tracker non-blockingly notifies the dispatcher. While
foreground ownership is active, it invokes the foreground WebDAV coordinator
through the existing settings gate. It never schedules WorkManager for that
foreground path.

The dispatcher admits at most one operation at a time and coalesces all
mutations received during ownership admission or synchronization into one
follow-up attempt. Errors are caught and optionally reported; they do not block
the repository mutation. When ownership becomes inactive, the lifecycle owner
first removes the heartbeat and then hands unresolved pending work to
WorkManager. The background worker remains Hive-free, immutable, and
remote-wins.

## TDD Evidence

The new tests were first run red for the absent dispatcher/tracker injection,
lifecycle callback, and admission-race coalescing behavior. They now cover:

- A committed active-foreground mutation invokes foreground synchronization and
  does not use WorkManager scheduling.
- Rapid mutations during an active synchronization yield one follow-up attempt.
- Mutations received before foreground ownership resolves also coalesce.
- Lifecycle deactivation notifies the foreground dispatcher after heartbeat
  removal.

## Verification

- `flutter test test/data/sync test/data/services/data_transfer_service_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

All commands passed on 2026-07-24.

## Residual Concern

The revision/metadata remain the durable indication of unsynchronized local
state. A foreground synchronization failure while the app remains active is
reported and waits for the next mutation, startup synchronization, or the
inactive WorkManager handoff; the dispatcher does not claim a failed sync was
successful.
