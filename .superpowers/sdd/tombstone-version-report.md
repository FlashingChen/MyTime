# Tombstone Version Conflict Self-Review

## Root Cause

`SyncMergeService` previously let `preferLocal` or `preferRemote` decide an
entity-versus-valid-tombstone conflict without comparing per-entity versions.
Consequently, a policy could revive an older entity or discard a newer update.

## Resolution

- Valid tombstones remain limited to the existing 90-day window.
- A tombstone and an entity now compare UTC `deletedAt` with the selected
  entity's `updatedAt`.
- The strictly newer version wins. Equal timestamps or a missing entity
  `updatedAt` fall back to the explicit foreground-local/background-remote
  policy.
- Existing metadata absence behavior and expired-tombstone pruning remain
  unchanged.

## Regression Coverage

- Records: older deletion/newer update, newer deletion/older update, and both
  policy outcomes for equal timestamps.
- Categories: older deletion/newer update and newer deletion/older update.
- Background `SyncService` retry: a Worker old entity snapshot does not revive
  a newer remote tombstone after a `412` retry.

## Validation

- `flutter test test/data/sync/sync_merge_service_test.dart test/data/sync/sync_service_test.dart`: 26 passed.
- `flutter analyze`: no issues.
- `flutter test`: 243 passed.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.
