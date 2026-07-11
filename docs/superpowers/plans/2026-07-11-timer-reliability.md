# Timer Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair foreground timer updates and make active-timer persistence safe across app lifecycle transitions.

**Architecture:** The BLoC starts in-memory timing before any asynchronous write. Persistence is an isolated store operation for the immutable start time. Restore is guarded so its asynchronous result cannot replace newer state.

**Tech Stack:** Flutter, Dart, flutter_bloc, shared_preferences, flutter_test, bloc_test.

## Global Constraints

- Do not add dependencies.
- Use BLoC and repository boundaries already established by the app.
- Use simplified-Chinese UI text unchanged and preserve the prototype’s UI.
- All public classes retain `///` documentation comments.
- Update `CHANGELOG.md` under `[Unreleased]`.

---

### Task 1: Establish timer persistence regression tests

**Files:**
- Modify: `test/blocs/timer/timer_bloc_test.dart`
- Modify: `lib/data/repositories/active_timer_repository.dart`
- Modify: `lib/blocs/timer/timer_bloc.dart`

**Interfaces:**
- Consumes: `TimerStarted`, `RestoreTimer`, `TimerRunInProgress`.
- Produces: `ActiveTimerStore` abstraction and tests for delayed/failed persistence.

- [ ] **Step 1: Write failing tests**

Add a delayed in-memory `ActiveTimerStore` test double. Assert that `TimerStarted` immediately makes `bloc.state` a `TimerRunInProgress` before its pending `saveStartTime` future completes, and that a running state receives a later ticker update. Add a failed-write store test that still reaches a later ticker update. Add a restore test in which a pending restore completes after `TimerStarted`; assert that the manual start remains current.

- [ ] **Step 2: Run the targeted tests to verify failure**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`

Expected: FAIL because the current BLoC awaits storage before emitting and permits a delayed restore to emit stale state.

- [ ] **Step 3: Implement the minimal store boundary and BLoC ordering**

Define `abstract interface class ActiveTimerStore` with `saveStartTime`, `getStartTime`, and `clear`. Have `ActiveTimerRepository` implement it. In `TimerBloc`, emit and start the ticker immediately; run the save in a guarded, non-blocking helper. Ignore a restore completion if the timer state changed after restore began.

- [ ] **Step 4: Run targeted tests to verify success**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`

Expected: PASS with every timer regression test green.

### Task 2: Remove lifecycle persistence race and document behavior

**Files:**
- Modify: `lib/blocs/timer/timer_event.dart`
- Modify: `lib/ui/app_shell.dart`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: persistence performed at `TimerStarted`.
- Produces: timer events with no redundant lifecycle persistence request.

- [ ] **Step 1: Write the failing behavioral test**

Add or retain a BLoC test proving that stopping clears the persisted start time after a running session; it represents the no-resurrection guarantee once lifecycle persistence is removed.

- [ ] **Step 2: Run the targeted test to establish the existing safety boundary**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`

Expected: PASS for stop/reset clearing, while the new Task 1 tests identify the actual start/restore failure.

- [ ] **Step 3: Implement the minimal lifecycle cleanup**

Remove `TimerPersistRequested`, remove the `WidgetsBindingObserver` implementation from `app_shell.dart`, and revise the existing unreleased changelog text to describe immediate persistence at start and safe restoration.

- [ ] **Step 4: Verify all behavior**

Run: `flutter analyze && flutter test`

Expected: analyzer reports no issues and all tests pass.
