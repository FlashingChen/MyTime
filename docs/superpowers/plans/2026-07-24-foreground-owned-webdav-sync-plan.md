# Foreground-Owned WebDAV Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep WorkManager from opening Hive while the foreground app owns synchronization, while preserving safe background WebDAV uploads when the app is inactive.

**Architecture:** A foreground lifecycle observer writes a short-lived UTC heartbeat to existing SharedPreferences. The WorkManager callback checks that heartbeat before Hive initialization and returns if the foreground is active. Background synchronization reads raw Hive box values without repository default seeding and uploads its merge without applying a local snapshot. Foreground mutation serialization remains process-local; the unsafe stale lease-file protocol is removed.

**Tech Stack:** Flutter/Dart, WidgetsBindingObserver, SharedPreferences, Hive, workmanager, flutter_test.

## Global Constraints

- Do not introduce dependencies.
- Use existing `PreferencesStore` and `SharedPreferencesStore` for ownership state.
- Foreground heartbeat refresh interval is 30 seconds; fresh threshold is 90 seconds.
- WorkManager must check ownership before `HiveHelper.init()` or opening any Hive box.
- Background sync must not write records, categories, or seeded defaults to Hive.
- Existing conditional PUT, optional LOCK, 412 retries, and 90-day tombstones remain intact.
- Run format check, `flutter analyze`, `flutter test`, and `flutter build apk --debug` before completion.

---

### Task 1: Add Foreground Ownership Heartbeat

**Files:**
- Create: `lib/data/sync/foreground_sync_ownership.dart`
- Create: `test/data/sync/foreground_sync_ownership_test.dart`
- Modify: `lib/main.dart:1-31`

**Interfaces:**
- Consumes: `PreferencesStore.getString`, `setString`, and `remove`.
- Produces: `ForegroundSyncOwnership`, with `Future<void> activate()`, `Future<void> refresh()`, `Future<void> deactivate()`, and `Future<bool> isForegroundActive()`.

- [ ] **Step 1: Write failing ownership tests**

```dart
test('treats a recent heartbeat as an active foreground owner', () async {
  final store = _MemoryPreferences();
  final ownership = ForegroundSyncOwnership(
    preferences: store,
    clock: () => DateTime.utc(2026, 7, 24, 9),
  );

  await ownership.activate();

  expect(await ownership.isForegroundActive(), isTrue);
});

test('treats a heartbeat older than 90 seconds as inactive', () async {
  final store = _MemoryPreferences()
    ..values['webdav.foreground.heartbeat'] =
        DateTime.utc(2026, 7, 24, 8, 58, 29).toIso8601String();
  final ownership = ForegroundSyncOwnership(
    preferences: store,
    clock: () => DateTime.utc(2026, 7, 24, 9),
  );

  expect(await ownership.isForegroundActive(), isFalse);
});

test('removes its heartbeat when deactivated', () async {
  final store = _MemoryPreferences();
  final ownership = ForegroundSyncOwnership(preferences: store);
  await ownership.activate();

  await ownership.deactivate();

  expect(store.values['webdav.foreground.heartbeat'], isNull);
});
```

- [ ] **Step 2: Run the ownership test to verify it fails**

Run: `flutter test test/data/sync/foreground_sync_ownership_test.dart`

Expected: compilation failure because `ForegroundSyncOwnership` does not exist.

- [ ] **Step 3: Implement the ownership object and lifecycle observer**

```dart
class ForegroundSyncOwnership {
  ForegroundSyncOwnership({
    required PreferencesStore preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _clock = clock ?? DateTime.now;

  static const heartbeatKey = 'webdav.foreground.heartbeat';
  static const refreshInterval = Duration(seconds: 30);
  static const activeWindow = Duration(seconds: 90);

  final PreferencesStore _preferences;
  final DateTime Function() _clock;

  Future<void> activate() => refresh();

  Future<void> refresh() => _preferences.setString(
    heartbeatKey,
    _clock().toUtc().toIso8601String(),
  );

  Future<void> deactivate() => _preferences.remove(heartbeatKey);

  Future<bool> isForegroundActive() async {
    final value = await _preferences.getString(heartbeatKey);
    final heartbeat = value == null ? null : DateTime.tryParse(value)?.toUtc();
    return heartbeat != null &&
        _clock().toUtc().difference(heartbeat) <= activeWindow;
  }
}
```

Add a small `WidgetsBindingObserver` owner in `main.dart` that activates at startup, schedules `Timer.periodic(ForegroundSyncOwnership.refreshInterval, ...)`, refreshes in `resumed` and `inactive`, and cancels/removes on `paused`, `hidden`, and `detached`.

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/data/sync/foreground_sync_ownership_test.dart && flutter analyze`

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/foreground_sync_ownership.dart test/data/sync/foreground_sync_ownership_test.dart lib/main.dart
```

### Task 2: Block WorkManager Before Hive Setup

**Files:**
- Modify: `lib/data/sync/webdav_background_task.dart:20-63`
- Create: `lib/data/sync/webdav_background_runner.dart`
- Create: `test/data/sync/webdav_background_runner_test.dart`

**Interfaces:**
- Consumes: `ForegroundSyncOwnership.isForegroundActive()`.
- Produces: `WebDavBackgroundRunner.run()`, which returns `true` when a fresh foreground heartbeat makes the task skip before its `Future<void> Function()` Hive setup callback executes.

- [ ] **Step 1: Write failing admission tests**

```dart
test('skips before Hive setup when the foreground heartbeat is active', () async {
  var initializedHive = false;
  final runner = WebDavBackgroundRunner(
    ownership: _ActiveOwnership(true),
    initializeAndSynchronize: () async => initializedHive = true,
  );

  expect(await runner.run(), isTrue);
  expect(initializedHive, isFalse);
});

test('runs Hive setup when no foreground owner is active', () async {
  var initializedHive = false;
  final runner = WebDavBackgroundRunner(
    ownership: _ActiveOwnership(false),
    initializeAndSynchronize: () async => initializedHive = true,
  );

  expect(await runner.run(), isTrue);
  expect(initializedHive, isTrue);
});
```

- [ ] **Step 2: Run the admission test to verify it fails**

Run: `flutter test test/data/sync/webdav_background_runner_test.dart`

Expected: compilation failure because `WebDavBackgroundRunner` does not exist.

- [ ] **Step 3: Implement the admission runner and use it from the callback**

```dart
class WebDavBackgroundRunner {
  WebDavBackgroundRunner({
    required ForegroundSyncOwnership ownership,
    required Future<void> Function() initializeAndSynchronize,
  }) : _ownership = ownership,
       _initializeAndSynchronize = initializeAndSynchronize;

  final ForegroundSyncOwnership _ownership;
  final Future<void> Function() _initializeAndSynchronize;

  Future<bool> run() async {
    if (await _ownership.isForegroundActive()) return true;
    await _initializeAndSynchronize();
    return true;
  }
}
```

In `callbackDispatcher`, construct `SharedPreferencesStore` and
`ForegroundSyncOwnership` first. Pass `HiveHelper.init()` and the existing
repository/sync setup into `initializeAndSynchronize`. Preserve the existing
error mapping: malformed configuration completes successfully; network errors
return `false` for WorkManager retry.

- [ ] **Step 4: Run tests and analyze**

Run: `flutter test test/data/sync/webdav_background_runner_test.dart && flutter analyze`

Expected: tests pass and analyzer reports no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/webdav_background_runner.dart test/data/sync/webdav_background_runner_test.dart lib/data/sync/webdav_background_task.dart
```

### Task 3: Make Background Snapshot Reads Non-Mutating

**Files:**
- Modify: `lib/data/sync/sync_local_store.dart:33-190`
- Modify: `lib/data/sync/webdav_background_task.dart:31-51`
- Modify: `test/data/sync/repository_sync_local_store_test.dart`

**Interfaces:**
- Consumes: raw `RecordRepository` and raw `CategoryRepository` stores.
- Produces: `RepositorySyncLocalStore.readReadOnly()`, returning a `SyncSnapshot` without calling repository methods that create default categories.

- [ ] **Step 1: Write a failing read-only snapshot test**

```dart
test('readReadOnly does not create default categories for an empty store', () async {
  final categories = _FakeCategoriesRepository([]);
  final store = RepositorySyncLocalStore(
    records: _FakeRecordsRepository([]),
    categories: categories,
    revision: _FakeRevisionStore(DateTime.utc(2026, 7, 24)),
  );

  final snapshot = await store.readReadOnly();

  expect(snapshot.categories, isEmpty);
  expect(categories.writeCalls, 0);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/sync/repository_sync_local_store_test.dart`

Expected: compilation failure because `readReadOnly` does not exist.

- [ ] **Step 3: Implement raw box-backed read-only snapshot access**

Add a constructor or explicit callback to `RepositorySyncLocalStore` for
read-only record/category lists. In the foreground constructor retain existing
repository `getAll()` behavior. In the background callback supply closures that
read `HiveRecordDataStore` and `HiveCategoryDataStore` values directly, without
calling `CategoryRepository.getAll()`.

```dart
Future<SyncSnapshot> readReadOnly() => _gate.run(() async {
  final records = await _readOnlyRecords!();
  final categories = await _readOnlyCategories!();
  return SyncSnapshot(
    records: records,
    categories: categories,
    updatedAt: await _revision.read(),
    metadata: await _metadata.read(),
  );
});
```

Make `SyncService` use this read-only operation only when
`applyMergedLocal == false`.

- [ ] **Step 4: Run read-only and sync tests**

Run: `flutter test test/data/sync/repository_sync_local_store_test.dart test/data/sync/sync_service_test.dart`

Expected: all tests pass; background synchronization does not seed or replace
Hive data.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/sync_local_store.dart lib/data/sync/webdav_background_task.dart test/data/sync/repository_sync_local_store_test.dart test/data/sync/sync_service_test.dart
```

### Task 4: Remove Lease Lock and Confirm PUT Content

**Files:**
- Modify: `lib/data/sync/sync_data_gate.dart`
- Modify: `lib/data/sync/webdav_sync_adapter.dart:54-88`
- Modify: `lib/data/sync/sync_service.dart:54-105`
- Modify: `test/data/sync/sync_data_gate_test.dart`
- Modify: `test/data/sync/webdav_sync_adapter_test.dart`
- Modify: `test/data/sync/sync_service_test.dart`

**Interfaces:**
- Consumes: `SyncSnapshot` equality and `SyncPreconditionFailed`.
- Produces: a process-local `SyncDataGate` and adapter `push` confirmation that either returns the ETag for the uploaded snapshot or throws `SyncPreconditionFailed`.

- [ ] **Step 1: Write failing confirmation tests**

```dart
test('retries when a PUT confirmation GET has another document', () async {
  final remote = _RemoteThatConfirmsDifferentDocument();

  await expectLater(
    SyncService(local: _Local(_snapshot('local')), remote: remote).synchronize(),
    throwsA(isA<SyncPreconditionFailed>()),
  );
});

test('does not use a filesystem lease to serialize a foreground gate', () async {
  final gate = SyncDataGate();
  await gate.run(() async {});
  expect(File('${Directory.systemTemp.path}/mytime_sync.mutex').existsSync(), isFalse);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/webdav_sync_adapter_test.dart test/data/sync/sync_service_test.dart`

Expected: confirmation test fails because a different GET document is accepted;
gate test fails because lease-file code remains.

- [ ] **Step 3: Implement minimal safe behavior**

Replace `SyncDataGate` with only its per-instance future queue; remove
`dart:io`, stale mutex state, and Zone reentrancy code. Foreground writes and
foreground replacement share the one instance created in `main.dart`.

After a PUT without ETag, `WebDavSyncAdapter` must GET a
`RemoteSyncDocument`, compare its `snapshot` to the pushed snapshot, and throw
`SyncPreconditionFailed` if they differ or the ETag is absent. Return the
confirmed ETag only for equal snapshots.

```dart
final confirmation = await pull();
if (confirmation == null ||
    confirmation.eTag == null ||
    confirmation.snapshot != snapshot) {
  throw const SyncPreconditionFailed();
}
return confirmation.eTag;
```

- [ ] **Step 4: Run focused tests and analyze**

Run: `flutter test test/data/sync/sync_data_gate_test.dart test/data/sync/webdav_sync_adapter_test.dart test/data/sync/sync_service_test.dart && flutter analyze`

Expected: all tests pass and analyzer reports no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/data/sync/sync_data_gate.dart lib/data/sync/webdav_sync_adapter.dart lib/data/sync/sync_service.dart test/data/sync/sync_data_gate_test.dart test/data/sync/webdav_sync_adapter_test.dart test/data/sync/sync_service_test.dart
```

### Task 5: Update Documentation and Verify the Complete Change

**Files:**
- Modify: `docs/architecture.md`
- Modify: `CHANGELOG.md`
- Modify: `README.md` if it documents background synchronization behavior

**Interfaces:**
- Consumes: the foreground ownership behavior from Tasks 1-4.
- Produces: documentation that says worker sync skips while a foreground heartbeat is active and background sync does not apply Hive snapshots.

- [ ] **Step 1: Add documentation assertions to existing tests where practical**

```dart
test('worker skip returns before the configured Hive initializer', () async {
  var hiveOpened = false;
  final runner = WebDavBackgroundRunner(
    ownership: _ActiveOwnership(true),
    initializeAndSynchronize: () async => hiveOpened = true,
  );

  await runner.run();

  expect(hiveOpened, isFalse);
});
```

- [ ] **Step 2: Update docs**

Add a concise architecture section stating: foreground owns Hive synchronization
while its 90-second heartbeat is fresh; WorkManager exits before Hive setup in
that state; background uploads merge output without replacing local Hive data.
Add the same behavior to `[Unreleased]` in `CHANGELOG.md`.

- [ ] **Step 3: Run the full quality gate**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Expected: format check succeeds, analyzer reports `No issues found!`, all tests
pass, and the debug APK is built.

- [ ] **Step 4: Commit**

```bash
git add docs/architecture.md CHANGELOG.md README.md test/data/sync/webdav_background_runner_test.dart
```
