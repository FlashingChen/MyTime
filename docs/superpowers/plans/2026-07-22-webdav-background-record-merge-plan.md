# WebDAV 后台同步与逐记录合并 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Android 上于本地记录或分类变更后自动执行一次安全的 WebDAV 同步，并通过 ETag、可选锁、墓碑和逐实体合并保护多设备数据。

**Architecture:** 保持 `TimeRecord` 与 `Category` 领域模型不变，在 SharedPreferences 中保存独立的同步元数据。传输层将 WebDAV 文档及其 ETag 作为原子值读写；协调器在共享数据门内执行本地快照读取、ID 级合并、条件上传和确认。Repository 写入装饰器仅在成功写入后更新实体元数据并投递唯一 Android 后台任务。

**Tech Stack:** Flutter/Dart、flutter_bloc、Hive CE、SharedPreferences、flutter_secure_storage、`workmanager ^0.9.0+3`、dart:io `HttpClient`、flutter_test。

## Global Constraints

- 仅新增 `workmanager ^0.9.0+3` 作为本功能的新依赖；先运行 `flutter pub get`，并遵循该版本公开 API。
- WebDAV 地址必须是 HTTPS、必须无 URL 内嵌凭据；密码只能经 `flutter_secure_storage` 读取。
- 不向 `TimeRecord`、`Category` 或 Bloc 写入同步字段；Hive 既有 DTO 的 type ID、字段号和数据兼容性不得改变。
- 同一 ID 的不同实体内容冲突时本机优先；不做字段级合并或冲突副本。
- 删除墓碑保留 90 天；在有效期内墓碑优先于同 ID 的实体。
- WebDAV 写入必须使用 `If-Match` 或首次创建时的 `If-None-Match: *`；`LOCK` 仅为兼容性可选优化。
- Android 后台任务必须使用唯一任务和已连接网络约束；不做固定周期同步。后台 isolate 必须独立初始化存储和安全凭据。
- 所有用户可见文案使用简体中文；同步 UI、`design-demos/mytime-prototype.html`、`README.md`、`docs/architecture.md` 和 `CHANGELOG.md` 必须同步更新。
- 完成前运行 `dart format lib test`、`flutter analyze`、`flutter test`；不提交或还原用户已有工作区改动，除非用户明确要求。

---

## File Structure

| 文件 | 职责 |
| --- | --- |
| `lib/data/sync/sync_metadata.dart` | 同步实体、墓碑、ETag 和最近结果的不可变值对象。 |
| `lib/data/sync/sync_metadata_store.dart` | 独立于业务模型的同步元数据持久化边界及 SharedPreferences 实现。 |
| `lib/data/sync/sync_merge_service.dart` | 纯 Dart 的记录、分类、墓碑逐 ID 合并与 90 天清理。 |
| `lib/data/sync/sync_port.dart` | 版本 2 文档、带 ETag 的拉取、条件 PUT、可选锁的传输接口。 |
| `lib/data/sync/webdav_sync_adapter.dart` | WebDAV HTTP 编解码、ETag 条件头和 LOCK/UNLOCK 降级。 |
| `lib/data/sync/sync_service.dart` | 以合并结果替代快照 LWW 的同步编排和最多三次 412 重试。 |
| `lib/data/sync/sync_scheduler.dart` | 后台调度抽象、Android WorkManager 实现和 no-op 实现。 |
| `lib/data/sync/webdav_background_task.dart` | isolate 入口，重新构造存储、设置、协调器并执行同步。 |
| `lib/data/sync/sync_mutation_tracker.dart` | 成功本地写入后更新实体元数据并安排同步。 |
| `lib/data/sync/revision_tracking_repositories.dart` | 将记录/分类 ID 和删除事件传给新的 tracker。 |
| `lib/data/sync/sync_local_store.dart` | 原子应用合并快照并在成功后写入同步元数据。 |
| `lib/main.dart` | 初始化元数据、调度器、后台任务与依赖图。 |
| `lib/ui/pages/settings/widgets/webdav_sync_sheet.dart` | 自动同步说明、最近同步状态和新结果文案。 |
| `test/data/sync/*.dart` | 元数据、合并、协议、协调器、调度和变更追踪测试。 |

### Task 1: 建立同步元数据和版本 2 文档模型

**Files:**
- Create: `lib/data/sync/sync_metadata.dart`
- Create: `lib/data/sync/sync_metadata_store.dart`
- Create: `test/data/sync/sync_metadata_store_test.dart`
- Modify: `lib/data/sync/sync_port.dart`

**Consumes:** 现有 `PreferencesStore` 的 `getString`、`setString`、`remove`。

**Produces:**
- `SyncEntityKind { record, category }`
- `SyncEntityMetadata({required SyncEntityKind kind, required String id, DateTime? updatedAt, DateTime? deletedAt})`
- `SyncMetadata({required Map<String, SyncEntityMetadata> records, required Map<String, SyncEntityMetadata> categories, required String? eTag})`
- `SyncMetadataStore.read()`、`write(SyncMetadata)`、`markChanged(SyncEntityKind, String, DateTime)`、`markDeleted(SyncEntityKind, String, DateTime)`
- `RemoteSyncDocument({required SyncSnapshot snapshot, required SyncMetadata metadata, required String? eTag})`

- [ ] **Step 1: 写入失败测试，覆盖元数据 round-trip、单调时间和墓碑**

```dart
test('records an entity tombstone and retains the remote ETag', () async {
  final store = PreferencesSyncMetadataStore(_preferences);
  await store.markChanged(SyncEntityKind.record, 'record-1', utc(10));
  await store.markDeleted(SyncEntityKind.record, 'record-1', utc(12));
  await store.write((await store.read()).copyWith(eTag: '"etag-1"'));

  final metadata = await store.read();
  expect(metadata.records['record-1']!.updatedAt, utc(10));
  expect(metadata.records['record-1']!.deletedAt, utc(12));
  expect(metadata.eTag, '"etag-1"');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/sync/sync_metadata_store_test.dart`

Expected: FAIL，因为 `sync_metadata.dart` 和 `PreferencesSyncMetadataStore` 尚不存在。

- [ ] **Step 3: 实现不可变元数据和值对象，以及 JSON 偏好存储**

```dart
class SyncEntityMetadata {
  const SyncEntityMetadata({
    required this.kind,
    required this.id,
    this.updatedAt,
    this.deletedAt,
  });

  final SyncEntityKind kind;
  final String id;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
}

abstract interface class SyncMetadataStore {
  Future<SyncMetadata> read();
  Future<void> write(SyncMetadata metadata);
  Future<void> markChanged(SyncEntityKind kind, String id, DateTime changedAt);
  Future<void> markDeleted(SyncEntityKind kind, String id, DateTime deletedAt);
}
```

将完整元数据序列化到一个专用偏好键。`markChanged` 必须保留先前墓碑之外的最新时间；`markDeleted` 必须保留较晚删除时间并移除活动实体的时间。损坏 JSON 必须删除该键并返回空元数据。修改 `SyncSnapshot` 以持有 `SyncMetadata metadata`，构造函数默认空元数据，使当前调用点在本任务结束前仍可编译。

- [ ] **Step 4: 运行元数据测试和现有同步测试**

Run: `flutter test test/data/sync/sync_metadata_store_test.dart test/data/sync/preferences_sync_revision_store_test.dart`

Expected: PASS。

### Task 2: 实现纯逐实体合并和墓碑清理

**Files:**
- Create: `lib/data/sync/sync_merge_service.dart`
- Create: `test/data/sync/sync_merge_service_test.dart`
- Modify: `lib/data/sync/sync_port.dart`

**Consumes:** Task 1 的 `SyncSnapshot` 和 `SyncMetadata`。

**Produces:** `SyncMergeService({DateTime Function()? clock}).merge({required SyncSnapshot local, required SyncSnapshot remote}) -> SyncSnapshot`；合并结果包含清理后的元数据。

- [ ] **Step 1: 写入合并失败测试**

```dart
test('keeps unrelated entities from both devices and local content on conflict', () {
  final merged = service.merge(local: localWith('a', note: '本机'), remote: remoteWith('a', note: '远端')
    ..addRecord('b'));

  expect(merged.records.map((item) => item.id), containsAll(['a', 'b']));
  expect(merged.records.singleWhere((item) => item.id == 'a').note, '本机');
});

test('tombstone prevents an old remote record from returning for 90 days', () {
  final merged = service.merge(local: locallyDeleted('a', utc(20)), remote: remoteWith('a'));
  expect(merged.records, isEmpty);
  expect(merged.metadata.records['a']!.deletedAt, utc(20));
});

test('clears a retained record category when its category is tombstoned', () {
  final merged = service.merge(local: localCategoryDeleted('work'), remote: remoteRecord(categoryId: 'work'));
  expect(merged.records.single.categoryId, isNull);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/sync/sync_merge_service_test.dart`

Expected: FAIL，因为 `SyncMergeService` 不存在。

- [ ] **Step 3: 写入最小纯 Dart 合并实现**

```dart
SyncSnapshot merge({required SyncSnapshot local, required SyncSnapshot remote}) {
  final records = _mergeEntities<TimeRecord>(
    local: local.records,
    remote: remote.records,
    localMetadata: local.metadata.records,
    remoteMetadata: remote.metadata.records,
    same: _sameRecord,
  );
  final categories = _mergeEntities<Category>(
    local: local.categories,
    remote: remote.categories,
    localMetadata: local.metadata.categories,
    remoteMetadata: remote.metadata.categories,
    same: (left, right) => left == right,
  );
  final metadata = _pruneExpiredMetadata(
    records: recordMetadata,
    categories: categoryMetadata,
  );
  return _normalizeCategoryReferences(records, categories, metadata);
}
```

按 ID 建索引。有效墓碑优先；两个活动实体内容不同一律选本机；相同实体保留较晚 `updatedAt`；两个墓碑保留较晚 `deletedAt`。以 UTC `now - const Duration(days: 90)` 清除过期墓碑。合并后将无效分类引用设为 `null`，并在不产生至少一个分类时抛出 `ArgumentError`，而不是悄然删除全部数据。

- [ ] **Step 4: 扩充并运行合并测试**

新增“相同实体使用较新元数据”“两个墓碑选择较晚时间”“第 90 天边界仍保留、超过边界清理”“远端 v1 初始化的实体元数据”测试。

Run: `flutter test test/data/sync/sync_merge_service_test.dart`

Expected: PASS。

### Task 3: 升级 WebDAV 适配器为 ETag 条件协议和可选锁

**Files:**
- Modify: `lib/data/sync/sync_port.dart`
- Modify: `lib/data/sync/webdav_sync_adapter.dart`
- Modify: `test/data/sync/webdav_sync_adapter_test.dart`

**Consumes:** Task 1 的 `RemoteSyncDocument`、Task 2 的版本 2 快照元数据。

**Produces:**
- `SyncPort.pull() -> Future<RemoteSyncDocument?>`
- `SyncPort.push(RemoteSyncDocument document, {required String? ifMatch, required bool ifNoneMatch}) -> Future<String?>`
- `SyncPort.lock() -> Future<SyncLock?>` 和 `SyncPort.unlock(SyncLock lock) -> Future<void>`
- `SyncLock({required String token})`

- [ ] **Step 1: 写入 HTTP 失败测试**

```dart
test('sends If-Match and returns the PUT response ETag', () async {
  final eTag = await adapter.push(document, ifMatch: '"v1"', ifNoneMatch: false);
  expect(requests.last.headers['if-match'], '"v1"');
  expect(eTag, '"v2"');
});

test('uses If-None-Match when creating a missing document', () async {
  await adapter.push(document, ifMatch: null, ifNoneMatch: true);
  expect(requests.single.headers['if-none-match'], '*');
});

test('treats LOCK not implemented as unsupported instead of an error', () async {
  expect(await adapter.lock(), isNull);
});
```

- [ ] **Step 2: 运行适配器测试确认失败**

Run: `flutter test test/data/sync/webdav_sync_adapter_test.dart`

Expected: FAIL，现有 `SyncPort` 只有无条件 `pull` 和 `push`。

- [ ] **Step 3: 实现版本 1/2 编解码和协议头**

```dart
Future<RemoteSyncDocument?> pull() async {
  final response = await _request('GET', _endpoint, _headers, null);
  if (response.statusCode == HttpStatus.notFound) return null;
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('WebDAV GET failed: ${response.statusCode}');
  }
  return _decode(response.body).copyWith(eTag: response.headers['etag']);
}

Future<String?> push(
  RemoteSyncDocument document, {
  required String? ifMatch,
  required bool ifNoneMatch,
}) async {
  final headers = {..._headers, if (ifMatch != null) 'If-Match': ifMatch,
    if (ifNoneMatch) 'If-None-Match': '*'};
  final response = await _request('PUT', _endpoint, headers, jsonEncode(_encode(document)));
  if (response.statusCode == HttpStatus.preconditionFailed) throw const SyncPreconditionFailed();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('WebDAV PUT failed: ${response.statusCode}');
  }
  return response.headers['etag'];
}
```

将 `WebDavResponse` 扩展为 `headers`，并使测试注入 transport 能表达 ETag。解码版本 1 时以文档 `updatedAt` 生成每个记录和分类的活动元数据；编码始终输出版本 2、活动实体元数据和墓碑。LOCK 使用 `Timeout: Second-30`、解析 `Lock-Token`，仅对 `405`、`501` 返回 `null`；获得锁后 UNLOCK 发送 `Lock-Token`。其他锁错误照常抛出。

- [ ] **Step 4: 运行适配器测试**

Run: `flutter test test/data/sync/webdav_sync_adapter_test.dart`

Expected: PASS，包含 HTTPS/凭据拒绝、v1 兼容、v2 round-trip、条件头、412、LOCK 降级和 UNLOCK。

### Task 4: 将协调器改为原子合并、条件写入与有限重试

**Files:**
- Modify: `lib/data/sync/sync_local_store.dart`
- Modify: `lib/data/sync/sync_service.dart`
- Modify: `lib/data/sync/webdav_sync_coordinator.dart`
- Modify: `test/data/sync/sync_service_test.dart`
- Modify: `test/data/sync/webdav_sync_coordinator_test.dart`

**Consumes:** Task 2 的 `SyncMergeService` 和 Task 3 的条件 `SyncPort`。

**Produces:** `SyncService.synchronize() -> Future<SyncResult>`，其中 `SyncResult` 包含 `merged`、`uploaded`、`retryCount`；同步成功后本地数据、元数据和 ETag 同时确认。

- [ ] **Step 1: 写入协调器失败测试**

```dart
test('re-pulls, re-merges, and retries once after a precondition failure', () async {
  remote.pushes = [const SyncPreconditionFailed(), '"v3"'];
  final result = await service.synchronize();
  expect(remote.pullCount, 2);
  expect(result.retryCount, 1);
  expect(remote.lastPushed.records.single.note, '本机编辑');
});

test('always unlocks after a failed conditional PUT', () async {
  await expectLater(service.synchronize(), throwsA(isA<HttpException>()));
  expect(remote.unlockedTokens, ['opaquelocktoken:1']);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/data/sync/sync_service_test.dart test/data/sync/webdav_sync_coordinator_test.dart`

Expected: FAIL，因为服务仍按完整快照 `updatedAt` 比较且不支持条件写入。

- [ ] **Step 3: 实现最多三次的拉取、合并、写入循环**

```dart
Future<SyncResult> _synchronize() async {
  SyncLock? lock;
  try {
    for (var attempt = 0; attempt < 3; attempt++) {
      final local = await _local.read();
      final remote = await _remote.pull();
      lock ??= remote == null ? null : await _remote.lock();
      final merged = _merger.merge(local: local, remote: remote?.snapshot ?? _emptySnapshot());
      final eTag = await _remote.push(
        RemoteSyncDocument(snapshot: merged, metadata: merged.metadata),
        ifMatch: remote?.eTag,
        ifNoneMatch: remote == null,
      );
      await _local.replace(merged.copyWith(metadata: merged.metadata.copyWith(eTag: eTag ?? remote?.eTag)));
      return SyncResult(merged: true, uploaded: true, retryCount: attempt);
    }
  } on SyncPreconditionFailed {
    // The loop retries; after its third failed conditional PUT it throws.
  } finally {
    if (lock != null) await _remote.unlock(lock);
  }
  throw const SyncConflictExhausted();
}
```

实际实现必须在每次 `SyncPreconditionFailed` 后进入下一次循环而非吞掉最后异常；不要在 PUT 成功前替换本地数据或更新 ETag。保留现有 Coordinator 的进程内 `_inFlight` 去重。将 `RepositorySyncLocalStore` 扩展为在同一 `SyncDataGate` 临界区内写业务快照、写修订时间和写元数据；任一失败时回滚业务快照和原元数据。

- [ ] **Step 4: 运行协调器和本地回滚测试**

Run: `flutter test test/data/sync/sync_service_test.dart test/data/sync/webdav_sync_coordinator_test.dart test/data/sync/repository_sync_local_store_test.dart`

Expected: PASS，覆盖双向合并、同 ID 本机优先、412 三次耗尽、无锁降级、锁释放、ETag 确认和回滚。

### Task 5: 在成功本地变更后调度唯一 Android 后台同步

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/sync/sync_scheduler.dart`
- Create: `lib/data/sync/webdav_background_task.dart`
- Modify: `lib/data/sync/sync_mutation_tracker.dart`
- Modify: `lib/data/sync/revision_tracking_repositories.dart`
- Modify: `lib/core/utils/hive_helper.dart`
- Modify: `lib/main.dart`
- Create: `test/data/sync/sync_scheduler_test.dart`
- Modify: `test/data/sync/revision_tracking_repositories_test.dart`

**Consumes:** Task 1 的 `SyncMetadataStore`，Task 4 的 Coordinator；`SettingsRepository.load()` 获取完整 WebDAV 凭据。

**Produces:**
- `SyncScheduler.schedule()` 和 `NoopSyncScheduler`
- `WorkmanagerSyncScheduler`，任务名 `mytime.webdav.sync`
- `SyncMutationTracker.markChanged(SyncEntityKind kind, String id)` 与 `markDeleted(SyncEntityKind kind, String id)`
- 顶层 `@pragma('vm:entry-point') void callbackDispatcher()`

- [ ] **Step 1: 添加依赖并编写调度失败测试**

在 `pubspec.yaml` 的 `dependencies` 增加：

```yaml
  workmanager: ^0.9.0+3
```

```dart
test('schedules one connected-network task after a successful record update', () async {
  await repository.update(record);
  expect(scheduler.requests, [
    const SyncScheduleRequest(
      uniqueName: 'mytime.webdav.sync',
      taskName: 'mytime.webdav.sync',
      requiresNetwork: true,
    ),
  ]);
});

test('does not schedule when the repository write fails', () async {
  await expectLater(repository.update(record), throwsStateError);
  expect(scheduler.requests, isEmpty);
});
```

- [ ] **Step 2: 获取依赖并运行失败测试**

Run: `flutter pub get && flutter test test/data/sync/sync_scheduler_test.dart test/data/sync/revision_tracking_repositories_test.dart`

Expected: FAIL，因为调度器和 ID 感知的 tracker 尚未实现。

- [ ] **Step 3: 实现调度器、变更追踪和后台 isolate**

```dart
abstract interface class SyncScheduler {
  Future<void> schedule();
}

class WorkmanagerSyncScheduler implements SyncScheduler {
  @override
  Future<void> schedule() => Workmanager().registerOneOffTask(
    'mytime.webdav.sync',
    'mytime.webdav.sync',
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
```

`SyncMutationTracker` 必须先用单调 UTC 时钟写指定实体的元数据，再调用 `scheduler.schedule()`。调度失败不能让已经持久化的用户写入以失败结束：保留已落盘元数据和待同步状态，记录可诊断错误，并在下一次本地变更或用户点按“立即同步”时再次尝试。记录 `add`、`update`、`delete` 分别传记录 ID；分类 `delete` 传分类 ID。`reassignCategory` 和 `clearCategory` 必须先从 delegate 获取受影响记录 ID，并为每条被成功修改的记录标记变更。

顶层后台入口必须调用 `WidgetsFlutterBinding.ensureInitialized()`、`HiveHelper.init()`、打开 records/categories box、创建 `SharedPreferencesStore`、`SettingsRepository` 和 `PreferencesSyncMetadataStore`，然后使用原始 Repository、共享 `SyncDataGate` 和 `WebDavSyncCoordinator` 执行同步。设置不完整时返回成功且不联网；认证、格式或配置失败返回 `false`（不重试）；网络、超时、`SyncPreconditionFailed` 和 `SyncConflictExhausted` 返回 `false` 交给 WorkManager 退避。`main` 初始化 `Workmanager().initialize(callbackDispatcher)`，并将同一调度器注入 tracker。

- [ ] **Step 4: 运行调度和追踪测试**

Run: `flutter test test/data/sync/sync_scheduler_test.dart test/data/sync/revision_tracking_repositories_test.dart`

Expected: PASS，覆盖唯一任务请求、网络约束、成功后调度、删除墓碑、失败写入不调度、批量受影响记录全部标记。

### Task 6: 更新设置反馈、原型和项目文档并全量验证

**Files:**
- Modify: `lib/ui/pages/settings/widgets/webdav_sync_sheet.dart`
- Create: `test/ui/pages/settings/widgets/webdav_sync_sheet_test.dart`
- Modify: `design-demos/mytime-prototype.html`
- Modify: `README.md`
- Modify: `docs/architecture.md`
- Modify: `CHANGELOG.md`

**Consumes:** Task 4 的 `SyncResult`、Task 5 的调度行为。

**Produces:** 一致说明自动后台同步、实体级本机优先冲突规则、90 天墓碑、ETag/可选锁与最近同步结果的 UI、原型和文档。

- [ ] **Step 1: 写入设置页失败 Widget 测试**

```dart
testWidgets('explains automatic sync and shows the latest successful sync', (tester) async {
  await tester.pumpWidget(buildSheet(lastSync: utc(12)));
  expect(find.text('本地编辑后将在网络可用时自动同步。'), findsOneWidget);
  expect(find.text('上次同步成功：2026-07-22 12:00'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/ui/pages/settings/widgets/webdav_sync_sheet_test.dart`

Expected: FAIL，因为设置页仍显示仅手动、整数据集 LWW 的文案，且没有最近状态。

- [ ] **Step 3: 更新 UI、原型和文档中的精确行为**

设置页副标题替换为“本地编辑后将在网络可用时自动同步。同一记录冲突时保留本机版本。”；成功后显示“同步成功：已合并记录并安全上传。”，并显示由同步元数据保存的最近成功时间。保留“立即同步”作为手动触发入口。将 `_messageFor` 扩展为 `SyncConflictExhausted`、条件写入和锁失败的可理解中文提示，且不得泄露 URL 密码或响应内容。

原型 WebDAV 弹窗使用完全相同的副标题、成功状态和按钮交互说明。README 与架构文档删除“无后台自动同步、ETag/文件锁或逐记录合并”的过期描述，写入新边界。向 `CHANGELOG.md` 的 `[Unreleased]` 增加一条中文变更说明。

- [ ] **Step 4: 运行格式、静态分析和完整测试**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: 格式化无后续 diff，`flutter analyze` 无问题，全部测试 PASS。

- [ ] **Step 5: Android 设备验证**

在两台配置相同 WebDAV 的 Android 设备上验证：设备 A 新增记录后离开应用，网络恢复时远端出现新记录；设备 B 下次同步合并该记录；两端同时编辑同 ID 后，发起同步的设备保留其本机内容；设备 A 删除记录后设备 B 的旧副本在 90 天内不会复活。记录设备型号、Android 版本、WebDAV 服务和验证日期到 PR 描述或测试记录，不写入含密码的仓库文件。

## Self-Review

- Spec coverage: Task 1 覆盖元数据与 v1 迁移数据模型；Task 2 覆盖记录/分类逐 ID 合并、90 天墓碑和引用修复；Task 3 覆盖 v2、ETag、LOCK/UNLOCK；Task 4 覆盖条件上传、412 有限重试、原子本地确认；Task 5 覆盖变更触发和 Android 后台 isolate；Task 6 覆盖 UI、原型、项目文档和全量验证。
- Placeholder scan: 未保留未决事项或泛化错误处理指令。每个实现任务都给出路径、接口、失败测试、命令和最小实现方向。
- Type consistency: `SyncMetadataStore`、`SyncMergeService`、条件 `SyncPort`、`SyncScheduler` 的名称和签名在后续任务中保持一致；实施时必须按 Task 1 的最终 `SyncSnapshot` 构造签名更新所有现有测试。
