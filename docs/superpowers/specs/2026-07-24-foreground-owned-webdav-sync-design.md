# Foreground-Owned WebDAV Sync Design

## Goal

Prevent a foreground Flutter engine and a WorkManager engine from opening and
mutating the same Hive data at the same time. Preserve background WebDAV
synchronization when the application is not active.

## Ownership Model

The foreground application owns Hive-backed synchronization while it is
running. WorkManager must not open Hive or construct repositories while the
foreground ownership heartbeat is fresh.

When there is no fresh heartbeat, WorkManager owns the background sync attempt.
Its attempt may upload a merged WebDAV document, but it must not replace local
Hive snapshots. The next foreground synchronization applies remote changes to
the foreground repository graph.

## Foreground Heartbeat

`ForegroundSyncOwnership` stores a UTC timestamp under
`webdav.foreground.heartbeat` using the existing `PreferencesStore`.

- Register and write the timestamp during application startup, before any
  user-originated mutation can schedule work.
- Refresh the timestamp every 30 seconds while the application is in the
  foreground or inactive lifecycle state.
- Remove the timestamp when lifecycle state becomes `paused`, `detached`, or
  `hidden`.
- A heartbeat is fresh for 90 seconds. Missing, malformed, or expired values
  mean no foreground owner exists.
- Heartbeat writes and removal are best effort. An abnormal process death leaves
  a timestamp that naturally expires within 90 seconds.

The ownership timestamp is only a WorkManager admission check. It does not
coordinate local foreground mutations because those execute in the same
foreground repository graph.

## WorkManager Admission

The WorkManager callback reads the ownership heartbeat before initializing Hive,
opening boxes, loading repositories, or creating a sync local store.

- If the heartbeat is fresh, return successful completion immediately. The
  foreground mutation scheduler already queues a connected one-off sync, and
  the live foreground application may perform its own sync.
- If the heartbeat is absent or stale, initialize the background sync graph and
  run one conditional WebDAV synchronization.
- Background synchronization keeps `applyMergedLocal: false`; it never calls
  `replaceIfCurrent` and does not update Hive-backed record/category data.
- Background code must not call repository methods that seed defaults or
  otherwise write Hive while producing its snapshot. The sync local store needs
  a read-only background snapshot path that reads raw boxes without creating
  default categories.

## Local Serialization

Remove the stale lease-file protocol. The foreground is the only code path that
mutates foreground Hive while it is alive. In a background-only process, the
WorkManager callback is the only application sync owner.

Keep the process-local `SyncDataGate` to serialize foreground local mutations
and foreground snapshot replacement. It must not claim cross-engine locking
guarantees.

## WebDAV Confirmation

Conditional PUT remains mandatory:

- Existing documents use `If-Match` with the GET ETag.
- New documents use `If-None-Match: *`.
- HTTP 412 triggers a fresh pull/merge retry, up to the existing retry limit.
- LOCK remains optional and unsupported LOCK responses degrade to ETag-only
  synchronization.

If a successful PUT has no ETag response header, perform a GET confirmation.
The confirmation document must decode to the exact snapshot that was uploaded.
If its contents differ, treat it as a precondition conflict and retry rather
than persisting its ETag as confirmation of the uploaded snapshot.

## Merge Rules

Per-ID merge retains the existing invariant:

- Independent IDs are unioned.
- Same-ID entity conflicts use local values.
- A valid tombstone wins over an entity for 90 days, preventing offline copies
  from resurrecting deleted records or categories.
- Expired tombstones are pruned.

## Tests

Add or update tests for:

- A fresh heartbeat makes the WorkManager task return before Hive setup.
- A stale or absent heartbeat allows the worker to execute.
- Foreground lifecycle changes refresh and clear the heartbeat.
- Background snapshot reads do not seed default categories or mutate Hive.
- Foreground `SyncDataGate` remains process-local and has no stale lease logic.
- A PUT without ETag performs GET confirmation.
- A confirmation GET with a different document triggers the normal conflict
  retry path and does not persist an unrelated ETag.

Run `dart format --output=none --set-exit-if-changed lib test integration_test
test_driver`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
