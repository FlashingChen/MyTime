# Pending Sync Responsibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the responsibility to synchronize each published local WebDAV revision until the matching foreground attempt succeeds.

**Architecture:** A preferences-backed pending-revision store is the durable source of truth. Mutation publication records the monotonic UTC revision only after snapshot publication; foreground attempts compare-and-clear their captured token and otherwise hand off durable work. Import recovery includes the token, while the Hive-free worker treats a foreground heartbeat as retryable admission loss.

**Tech Stack:** Flutter, Dart, SharedPreferences, WorkManager, flutter_test.

## Global Constraints

- Do not add dependencies or change iOS files.
- Persist `webdav.sync.pending_revision` as a UTC ISO-8601 timestamp.
- Keep background workers Hive-free and remote-wins.
- Use strict TDD: run each new test red before its production implementation.

---

### Task 1: Durable Pending Revision Store

**Files:**
- Create: `lib/data/sync/sync_pending_state_store.dart`
- Create: `test/data/sync/sync_pending_state_store_test.dart`

- [ ] Write tests for malformed values, monotonic advancement, and compare-and-clear.
- [ ] Run `flutter test test/data/sync/sync_pending_state_store_test.dart` and observe missing-symbol failures.
- [ ] Implement the preferences adapter with UTC normalization and CAS clear.
- [ ] Re-run the focused test and format changed Dart files.

### Task 2: Publication And Import Transaction

**Files:**
- Modify: `lib/data/sync/sync_mutation_tracker.dart`
- Modify: `lib/data/services/import_recovery_journal.dart`
- Modify: `test/data/services/data_transfer_service_test.dart`

- [ ] Add red tests requiring token persistence after snapshot publication and before schedule/journal clear.
- [ ] Run the focused tests and observe failure.
- [ ] Persist the advanced revision before notification; capture and restore it through import recovery.
- [ ] Re-run focused tests.

### Task 3: Foreground Attempts And Lifecycle Handoff

**Files:**
- Modify: `lib/data/sync/foreground_sync_mutation_dispatcher.dart`
- Modify: `lib/main.dart`
- Modify: `test/data/sync/foreground_sync_mutation_dispatcher_test.dart`
- Modify: `test/data/sync/startup_webdav_sync_test.dart`

- [ ] Add red tests for failure scheduling, startup CAS, concurrent mutation, and reconstructed lifecycle handoff.
- [ ] Run focused tests and observe failure.
- [ ] Capture each attempt token, compare-clear on success, retain/schedule on failure, and make startup an explicit attempt.
- [ ] Re-run focused tests.

### Task 4: Retryable Worker Admission

**Files:**
- Modify: `lib/data/sync/webdav_background_runner.dart`
- Modify: `lib/data/sync/webdav_background_task.dart`
- Modify: `test/data/sync/webdav_background_runner_test.dart`
- Modify: `test/data/sync/webdav_background_task_test.dart`

- [ ] Add red tests for both heartbeat admission checks returning retry.
- [ ] Run focused tests and observe failure.
- [ ] Return WorkManager retry for active ownership while retaining existing safe-success and network-retry behavior.
- [ ] Re-run focused tests.

### Task 5: Documentation And Verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Create: `.superpowers/sdd/pending-sync-responsibility-report.md`

- [ ] Document durable responsibility and worker limits.
- [ ] Run focused tests, `flutter analyze`, full `flutter test`, debug APK build, and inspect the diff before committing.
