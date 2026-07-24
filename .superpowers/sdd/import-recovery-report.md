# Import Recovery Report

## Status

Implemented durable recovery for interrupted JSON imports. A journal is
persisted before Hive replacement and remains durable until the pre-import
records, categories, and exact synchronization preferences are restored or a
new import is fully committed.

## Recovery Behavior

- The journal contains validated prior records and categories plus the exact
  serialized sync snapshot, revision, and metadata preference values.
- Recovery attempts category replacement, record replacement, and each of the
  three preference restorations independently. Any failure preserves the
  journal for the next foreground startup attempt.
- Startup recovers before snapshot reconciliation, WorkManager initialization,
  and automatic foreground WebDAV synchronization.
- A successful import clears the journal after publishing the new snapshot and
  immediately before the import mutation notifies the scheduler.

## Test Coverage

- Double record-store write failure leaves the journal after immediate rollback
  fails; a later startup recovery restores entities and all sync preferences.
- A failed entity restoration still attempts exact snapshot, revision, and
  metadata restoration.
- Scheduler observation verifies the journal is cleared before scheduling after
  successful snapshot publication.
- Startup synchronization verifies recovery runs first.

## Verification

Run after the final scheduling-order change:

- `flutter test test/data/services/data_transfer_service_test.dart test/data/sync/startup_webdav_sync_test.dart`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `git diff --check`

## Concerns

- Recovery must wait for a successful Hive and SharedPreferences write. If the
  device has persistent storage failure, application startup fails rather than
  exposing a potentially mixed local/sync state; the journal is retained for a
  future retry.
