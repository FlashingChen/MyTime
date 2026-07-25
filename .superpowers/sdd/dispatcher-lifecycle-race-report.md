# Dispatcher Lifecycle Race Report

## Findings

### P1: Dispatcher admission could remain permanently locked

`ForegroundSyncMutationDispatcher._dispatch` awaited foreground ownership before
entering its `try/finally`. An inactive ownership result returned immediately,
and an ownership-check exception escaped. Both paths skipped the `finally` that
clears `_dispatching`, so later committed mutations were marked as follow-up
work but never dispatched.

The dispatcher now places ownership admission, foreground synchronization, and
their terminal returns inside one `try/finally`. Ownership-check errors are
reported and still release `_dispatching`. The existing background handoff in
`finally` remains conditional on inactive lifecycle ownership.

### P2: Stale lifecycle deactivation could overwrite a resume

`ForegroundSyncLifecycleOwner` serialized lifecycle operations but incremented
its generation only while deactivating. A rapid `paused` then `resumed` left
the earlier queued deactivation valid. It could run after the app had resumed,
remove the new heartbeat, and notify the dispatcher inactive.

Resuming now advances the generation too. Both the queued deactivation and
post-deactivation notification verify their captured generation before acting.
The resumed operation refreshes ownership and only then notifies the dispatcher
active. This preserves nonblocking UI callbacks while preventing obsolete
operations from changing dispatcher handoff state.

## TDD Evidence

The focused regression suite was first run red. It demonstrated:

- Inactive dispatcher admission kept `_dispatching` set, preventing the next
  active mutation from synchronizing.
- An ownership-check exception escaped the dispatcher and similarly blocked a
  later active mutation.
- A queued paused deactivation removed the heartbeat after an immediate resume.

The final tests cover:

- Inactive admission schedules WorkManager once, then a later active mutation
  synchronizes.
- Ownership-check failure releases the dispatcher so a later active mutation
  synchronizes.
- Immediate `paused` to `resumed` ignores stale deactivation, retains active
  ownership, and a foreground sync failure does not schedule WorkManager.

## Scope

Only the dispatcher, lifecycle owner, their focused tests, and this report were
changed. Existing uncommitted iOS configuration and Podfile files were not
touched.

## Residual Concern

Foreground synchronization errors remain intentionally best-effort while the
app is active. The durable mutation revision remains pending for a future
mutation, startup synchronization, or a genuine inactive lifecycle handoff.
