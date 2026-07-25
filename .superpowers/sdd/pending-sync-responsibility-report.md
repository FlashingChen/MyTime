# Pending Sync Responsibility Report

## Scope

Implemented durable WebDAV pending synchronization responsibility from a
preferences-backed UTC revision token through foreground, startup, import, and
background-worker boundaries.

## State Machine

- A successful local publication writes `webdav.sync.pending_revision` after
  its revision, metadata, and immutable snapshot have succeeded.
- The store removes malformed values, advances monotonically, and clears only
  via an exact revision compare-and-clear.
- A foreground or startup attempt captures the token before synchronizing;
  successful completion clears only that captured value.
- Failed foreground attempts retain the token and request WorkManager even when
  the app remains active. Scheduler failures are reported without deleting it.
- Import recovery journals the previous pending token. Pending-token failure
  remains within the import transaction and triggers its existing rollback.

## Worker Boundary

Workers remain Hive-free and use immutable snapshots with remote-wins merge.
Any foreground heartbeat admission result, including the check after settings
and snapshot reads, returns WorkManager retry. Network errors still retry;
invalid configuration and absent snapshots remain safe success. Worker success
does not clear the foreground-owned pending token.

## Verification

Focused pending-state, dispatcher, startup, import, and worker tests cover
malformed/monotonic/CAS tokens, failed scheduling responsibility, concurrent
mutation CAS protection, reconstructed lifecycle handoff, import publication
ordering, and heartbeat retry admission. Final command results are recorded in
the commit handoff response.
