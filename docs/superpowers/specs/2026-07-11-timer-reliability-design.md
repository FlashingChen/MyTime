# Timer Reliability Design

**Goal:** Keep the visible timer running immediately and accurately in the foreground, while preserving a running session across Android backgrounding and process death.

## Decision

The `TimerBloc` owns the in-memory ticker and must enter `TimerRunInProgress` synchronously when a start event arrives. Persisting the immutable start timestamp is a best-effort side effect: it must never delay state emission or ticker creation.

The active-timer repository exposes a small store interface so the BLoC can be tested against delayed and failed storage. A restoration request captures the state at request time and must not replace a timer that was manually started while storage was loading.

The lifecycle observer and `TimerPersistRequested` event are removed. The start timestamp is already durably written at the sole state transition that creates a running session; rewriting it on lifecycle changes adds no information and can race with stop/reset clearing the session.

## Required behavior

- Starting emits a running state and begins updates without waiting for persistence.
- Storage failure must not stop foreground elapsed-time updates.
- A restored timer derives duration from its saved absolute start time.
- A delayed restore cannot overwrite a newly started timer.
- Stop and reset clear the persisted session; confirmation records use the original start time.
- No dependency is added; the UI remains anchored to the existing prototype.

## Verification

Timer BLoC tests cover a delayed store write, continued updates, failed persistence, restore, and restore/start ordering. The project runs `flutter analyze` and the full `flutter test` suite.
