# MyTime 数据完整性与状态一致性 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让完成计时、分类删除、跨午夜时间线和统计边界场景保持数据正确、可恢复且可测试。

**Architecture:** 在既有 BLoC + Hive 结构上增加最小的工作流边界：`PersistedTimerSession` 表示运行/待确认状态；`CompleteTimerSession` 串联记录写入和会话清理；`RecordRepository` 的变更流驱动 `RecordsBloc` 刷新。保持现有 Hive 模型 typeId/fieldId，不引入依赖或全面目录迁移。

**Tech Stack:** Flutter、Dart、flutter_bloc、Hive CE、SharedPreferences、flutter_test、bloc_test。

## Global Constraints

- 不新增第三方依赖；安全存储、导入事务和 WebDAV 不属于本计划。
- 不修改 `ios/Runner.xcodeproj/project.pbxproj`、`ios/Runner.xcworkspace/contents.xcworkspacedata`。
- 保留用户现有 `lib/ui/pages/stats/stats_metrics.dart` 与 `test/ui/pages/stats/stats_metrics_test.dart` 未提交改动；不得回退或覆盖。
- 继续使用简体中文文案、BLoC、Hive 和 SharedPreferences。
- 每次行为修改先写失败测试，再写最小实现。
- 不创建 commit，除非用户明确要求；仓库规范禁止主动提交。
- 完成前运行 `flutter analyze` 与 `flutter test`。

---

## 文件职责

| 文件 | 职责 |
|---|---|
| `lib/data/models/time_record.dart` | 记录值对象及可空字段安全的 `copyWith`。 |
| `lib/data/repositories/record_repository.dart` | 记录持久化、边界校验、幂等 ID 写入和变更流。 |
| `lib/data/repositories/active_timer_repository.dart` | 运行/待确认计时会话的 SharedPreferences 兼容持久化。 |
| `lib/application/use_cases/complete_timer_session.dart` | 写入确定记录后清理 pending 会话的跨仓库工作流。 |
| `lib/blocs/timer/*` | 计时会话状态、恢复、确认完成和明确放弃。 |
| `lib/blocs/records/records_bloc.dart` | 订阅记录 Repository 变更流并安全释放订阅。 |
| `lib/ui/pages/home/*` | 由 `BlocListener` 打开确认 Sheet，显示重试/放弃交互。 |
| `lib/ui/pages/timeline/*` | 按日区间重叠筛选并裁剪跨午夜记录。 |
| `lib/ui/pages/stats/*` | 饼图选中 ID、零分钟 AI 防御、正确的月度上一周期。 |

## Task 1: 固化记录模型与 Repository 边界

**Files:**

- Modify: `lib/data/models/time_record.dart`
- Modify: `lib/data/repositories/record_repository.dart`
- Modify: `lib/data/repositories/category_repository.dart`
- Modify: `test/data/models/time_record_test.dart`
- Modify: `test/data/repositories/record_repository_test.dart`
- Modify: `test/data/repositories/category_repository_test.dart`

**Interfaces:**

- Produces `Stream<void> get changes` on `RecordRepository`.
- Produces `Future<TimeRecord> add(TimeRecord record)` that preserves non-empty IDs and is idempotent for an existing ID.
- Produces repository validation failures for invalid record time, category name and category color.

- [ ] **Step 1: Add failing model tests for nullable `copyWith` semantics**

```dart
test('copyWith preserves nullable fields when omitted', () {
  final original = TimeRecord(
    id: 'record-1',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 12, 9),
    endTime: DateTime(2026, 7, 12, 10),
    note: 'draft',
  );
  final changed = original.copyWith(startTime: DateTime(2026, 7, 12, 9, 30));
  expect(changed.categoryId, 'work');
  expect(changed.note, 'draft');
});

test('copyWith can explicitly clear nullable fields', () {
  final original = TimeRecord(
    id: 'record-1',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 12, 9),
    endTime: DateTime(2026, 7, 12, 10),
    note: 'draft',
  );
  final changed = original.copyWith(categoryId: null, note: null);
  expect(changed.categoryId, isNull);
  expect(changed.note, isNull);
});
```

- [ ] **Step 2: Run model tests and verify the preserve test fails**

Run: `flutter test test/data/models/time_record_test.dart`

Expected: the omitted `categoryId` is unexpectedly `null`.

- [ ] **Step 3: Implement sentinel-based `copyWith`**

```dart
const _unset = Object();

TimeRecord copyWith({
  String? id,
  Object? categoryId = _unset,
  Object? note = _unset,
  DateTime? startTime,
  DateTime? endTime,
  DateTime? createdAt,
}) => TimeRecord(
  id: id ?? this.id,
  categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
  note: identical(note, _unset) ? this.note : note as String?,
  startTime: startTime ?? this.startTime,
  endTime: endTime ?? this.endTime,
  createdAt: createdAt ?? this.createdAt,
);
```

Keep the private sentinel file-local and preserve all existing constructor fields.

- [ ] **Step 4: Add failing Repository validation and idempotency tests**

```dart
await expectLater(repo.add(recordWithEndBeforeStart), throwsArgumentError);

final saved = await repo.add(recordWithId('pending-id'));
final retried = await repo.add(recordWithId('pending-id'));
expect(retried.id, saved.id);
expect(repo.getAll(), hasLength(1));
```

Also assert blank category names and `#ABC` colors are rejected by `CategoryRepository.add`.

- [ ] **Step 5: Run focused Repository tests and verify they fail**

Run: `flutter test test/data/repositories/record_repository_test.dart test/data/repositories/category_repository_test.dart`

Expected: invalid records/categories are accepted and duplicated IDs create a second logical write.

- [ ] **Step 6: Implement validation, ID preservation and record change notifications**

```dart
final _changes = StreamController<void>.broadcast();
Stream<void> get changes => _changes.stream;

void _validate(TimeRecord record) {
  if (!record.endTime.isAfter(record.startTime)) {
    throw ArgumentError.value(record, 'record', '结束时间必须晚于开始时间');
  }
}

Future<TimeRecord> add(TimeRecord record) async {
  _validate(record);
  final id = record.id.isEmpty ? _uuid.v4() : record.id;
  final existing = _box.get(id);
  if (existing != null) return existing;
  final saved = record.copyWith(id: id);
  await _box.put(id, saved);
  _changes.add(null);
  return saved;
}
```

Notify after successful add, update, delete, `reassignCategory` and `clearCategory`. Use a private category validation helper matching `RegExp(r'^#[0-9A-Fa-f]{6}$')`.

- [ ] **Step 7: Run focused tests and format touched files**

Run: `flutter test test/data/models/time_record_test.dart test/data/repositories/record_repository_test.dart test/data/repositories/category_repository_test.dart`

Expected: PASS.

Run: `dart format lib/data/models/time_record.dart lib/data/repositories/record_repository.dart lib/data/repositories/category_repository.dart test/data/models/time_record_test.dart test/data/repositories/record_repository_test.dart test/data/repositories/category_repository_test.dart`

Expected: files formatted without analyzer errors.

## Task 2: 持久化运行和待确认计时会话

**Files:**

- Modify: `lib/data/repositories/active_timer_repository.dart`
- Modify: `lib/blocs/timer/timer_event.dart`
- Modify: `lib/blocs/timer/timer_state.dart`
- Modify: `lib/blocs/timer/timer_bloc.dart`
- Modify: `test/data/repositories/active_timer_repository_test.dart`
- Modify: `test/blocs/timer/timer_bloc_test.dart`

**Interfaces:**

```dart
enum PersistedTimerStatus { running, pendingConfirmation }

class PersistedTimerSession {
  const PersistedTimerSession({
    required this.id,
    required this.startTime,
    required this.status,
    this.stoppedAt,
  });
  final String id;
  final DateTime startTime;
  final PersistedTimerStatus status;
  final DateTime? stoppedAt;
}

abstract interface class ActiveTimerStore {
  Future<void> save(PersistedTimerSession session);
  Future<PersistedTimerSession?> load();
  Future<void> clear();
}
```

- [ ] **Step 1: Add failing storage compatibility tests**

```dart
test('loads a legacy start time as a running session', () async {
  SharedPreferences.setMockInitialValues({
    'active_timer_start_time': '2026-07-12T09:00:00.000',
  });
  final session = await ActiveTimerRepository().load();
  expect(session!.status, PersistedTimerStatus.running);
});

test('round-trips a pending confirmation session', () async {
  await store.save(pendingSession);
  expect(await store.load(), pendingSession);
});
```

- [ ] **Step 2: Run active timer repository tests and verify failures**

Run: `flutter test test/data/repositories/active_timer_repository_test.dart`

Expected: session API is absent.

- [ ] **Step 3: Replace start-time-only storage with a versioned JSON session while retaining legacy read support**

Use a new `active_timer_session` key containing `id`, `status`, `startTime`, optional `stoppedAt`; parse timestamps as UTC ISO-8601. On a successful new-format save, remove the old start-time key. Invalid JSON/date values return `null` after removing the corrupt session key.

- [ ] **Step 4: Add failing BLoC tests for pending confirmation restoration**

```dart
bloc.add(TimerStopped());
await pumpEventQueue();
expect(bloc.state, isA<TimerRunComplete>());
expect(store.lastSaved.status, PersistedTimerStatus.pendingConfirmation);

final restored = TimerBloc(store)..add(RestoreTimer());
expect(restored.state, isA<TimerRunComplete>());
```

Also add tests for `TimerConfirmationCompleted` returning to `TimerInitial` without clearing storage, and `TimerDiscarded` clearing the session.

- [ ] **Step 5: Run timer BLoC tests and verify failures**

Run: `flutter test test/blocs/timer/timer_bloc_test.dart`

Expected: no pending session status or completion/discard events exist.

- [ ] **Step 6: Implement session-aware timer state transitions**

`TimerRunInProgress` and `TimerRunComplete` carry a stable session ID. `TimerStopped` captures `stoppedAt` once, emits `TimerRunComplete(startTime, stoppedAt)`, cancels the ticker and queues a pending session save. `RestoreTimer` maps running sessions to progress and pending sessions to complete state. `TimerDiscarded` clears storage; `TimerConfirmationCompleted` emits initial state only after `CompleteTimerSession` has cleared storage.

- [ ] **Step 7: Run focused tests and format timer files**

Run: `flutter test test/data/repositories/active_timer_repository_test.dart test/blocs/timer/timer_bloc_test.dart`

Expected: PASS.

## Task 3: 完成计时 UseCase 与确认 Sheet

**Files:**

- Create: `lib/application/use_cases/complete_timer_session.dart`
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/home/home_page.dart`
- Modify: `lib/ui/pages/home/widgets/confirm_bottom_sheet.dart`
- Modify: `test/ui/pages/home/home_page_test.dart`
- Create: `test/application/use_cases/complete_timer_session_test.dart`

**Interfaces:**

```dart
class CompleteTimerSession {
  CompleteTimerSession(this._records, this._timerStore);

  Future<void> call({
    required PersistedTimerSession session,
    required String categoryId,
    String? note,
  });
}
```

`main.dart` provides this use case with `RepositoryProvider.value`. `ConfirmBottomSheet.onConfirm` is `Future<void> Function(String categoryId, String? note)` and displays failures locally without closing.

- [ ] **Step 1: Add failing idempotent completion UseCase tests**

```dart
await useCase(session: pending, categoryId: 'work');
expect(await store.load(), isNull);
expect(records.getAll(), hasLength(1));

await useCase(session: pending, categoryId: 'work');
expect(records.getAll(), hasLength(1));
```

Add a failing-record-store test asserting that a failed write leaves the pending session untouched.

- [ ] **Step 2: Run UseCase tests and verify failure**

Run: `flutter test test/application/use_cases/complete_timer_session_test.dart`

Expected: file and `CompleteTimerSession` do not exist.

- [ ] **Step 3: Implement `CompleteTimerSession`**

Build the `TimeRecord` with `id: session.id`, `startTime: session.startTime`, `endTime: session.stoppedAt!`, and normalized optional note. Call `RecordRepository.add` before `ActiveTimerStore.clear`. Do not clear when record write fails. Retry is safe because Task 1 preserves non-empty IDs idempotently.

- [ ] **Step 4: Add failing Home/Sheet behavior tests**

```dart
testWidgets('uses stoppedAt after waiting in confirmation sheet', (tester) async {
  final stoppedAt = DateTime(2026, 7, 12, 9, 30);
  await tester.pumpWidget(buildHomeWithPendingSession(stoppedAt));
  await tester.pump(const Duration(minutes: 5));
  await tester.tap(find.text('确认保存'));
  expect(records.getAll().single.endTime, stoppedAt);
});

testWidgets('does not dismiss confirmation sheet when saving fails', (tester) async {
  await tester.pumpWidget(buildHomeWithFailingCompletion());
  await tester.tap(find.text('确认保存'));
  await tester.pump();
  expect(find.text('保存失败，请重试'), findsOneWidget);
  expect(find.text('记录详情'), findsOneWidget);
});
```

Also assert that a sheet dismissal gesture is unavailable and explicit discard requires a confirmation dialog.

- [ ] **Step 5: Run Home tests and verify failure**

Run: `flutter test test/ui/pages/home/home_page_test.dart`

Expected: current page opens a dismissible Sheet from `build` and has no async save failure state.

- [ ] **Step 6: Implement single-trigger confirmation UI**

Move modal opening to `BlocListener<TimerBloc, TimerState>`. Use `showModalBottomSheet` with `isDismissible: false` and `enableDrag: false`. Pass fixed `startTime`/`stoppedAt` into the Sheet. Await `CompleteTimerSession`; on success dispatch `TimerConfirmationCompleted` and close; on failure retain the Sheet and render `保存失败，请重试`. Implement explicit discard confirmation that dispatches `TimerDiscarded` only after approval.

- [ ] **Step 7: Run UseCase and Home tests**

Run: `flutter test test/application/use_cases/complete_timer_session_test.dart test/ui/pages/home/home_page_test.dart`

Expected: PASS.

## Task 4: 用记录变更流同步分类删除

**Files:**

- Modify: `lib/blocs/records/records_bloc.dart`
- Modify: `lib/blocs/categories/categories_bloc.dart`
- Modify: `lib/core/utils/category_lookup.dart`
- Modify: `test/blocs/records/records_bloc_test.dart`
- Modify: `test/blocs/categories/categories_bloc_test.dart`
- Modify: `test/ui/pages/home/widgets/recent_records_list_test.dart`

**Interfaces:**

- `RecordsBloc` holds `StreamSubscription<void>? _changesSubscription` and dispatches `LoadRecords` when `RecordRepository.changes` emits.
- `CategoriesBloc(CategoryRepository repository, RecordRepository recordRepository)` requires the record repository.

- [ ] **Step 1: Add failing category deletion integration tests**

```dart
categoriesBloc.add(const CategoryDeleted('work'));
await pumpEventQueue();
expect(recordsBloc.state, isA<RecordsLoaded>());
expect(recordsBloc.state.records.single.categoryId, isNull);
```

Add a widget assertion that a missing/null category renders `未分类`, not `其他`.

- [ ] **Step 2: Run focused BLoC/widget tests and verify failure**

Run: `flutter test test/blocs/categories/categories_bloc_test.dart test/blocs/records/records_bloc_test.dart test/ui/pages/home/widgets/recent_records_list_test.dart`

Expected: records state remains stale or the test composition cannot observe a repository change.

- [ ] **Step 3: Subscribe RecordsBloc to repository changes and require cleanup dependency**

Subscribe after registering event handlers; listener calls `add(LoadRecords())` unless the BLoC is closed. Cancel the subscription before `super.close()`. Remove optional `RecordRepository?`; perform `await _recordRepository.clearCategory(event.id)` before deleting. Keep the one-category guard.

- [ ] **Step 4: Make category lookup explicit for unknown IDs**

Return the existing `未分类` category for `null` and unknown IDs. Do not use `DefaultCategories.byId` as a fallback for unknown persisted IDs.

- [ ] **Step 5: Run focused tests**

Run: `flutter test test/blocs/categories/categories_bloc_test.dart test/blocs/records/records_bloc_test.dart test/ui/pages/home/widgets/recent_records_list_test.dart`

Expected: PASS.

## Task 5: 裁剪跨午夜时间线记录

**Files:**

- Modify: `lib/data/repositories/record_repository.dart`
- Modify: `lib/ui/pages/timeline/timeline_page.dart`
- Modify: `lib/ui/pages/timeline/timeline_layout.dart`
- Modify: `test/data/repositories/record_repository_test.dart`
- Modify: `test/ui/pages/timeline/timeline_layout_test.dart`
- Modify: `test/ui/pages/timeline/timeline_page_test.dart`

**Interfaces:**

```dart
List<TimeRecord> recordsOverlappingDay(List<TimeRecord> records, DateTime day)
```

The helper returns clipped display records, never persists the clipped values.

- [ ] **Step 1: Add failing cross-midnight tests**

```dart
final record = TimeRecord(
  id: 'overnight',
  categoryId: 'work',
  startTime: DateTime(2026, 7, 11, 23),
  endTime: DateTime(2026, 7, 12, 1),
);
expect(repo.getByDate(DateTime(2026, 7, 12)), contains(record));
expect(day11.single.endTime, DateTime(2026, 7, 12));
expect(day12.single.startTime, DateTime(2026, 7, 12));
```

- [ ] **Step 2: Run timeline and repository tests and verify failure**

Run: `flutter test test/data/repositories/record_repository_test.dart test/ui/pages/timeline/timeline_layout_test.dart test/ui/pages/timeline/timeline_page_test.dart`

Expected: second-day lookup omits the record and layout uses an invalid end minute.

- [ ] **Step 3: Implement overlap queries and display clipping**

Use `record.startTime.isBefore(dayEnd) && record.endTime.isAfter(dayStart)` in `getByDate`. In `TimelinePage`, filter all loaded records through a pure clip helper before `TimelineLayout.calculate`; the helper creates fresh `TimeRecord` instances preserving id, category, note and `createdAt`.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/data/repositories/record_repository_test.dart test/ui/pages/timeline/timeline_layout_test.dart test/ui/pages/timeline/timeline_page_test.dart`

Expected: PASS.

## Task 6: 加固统计边界场景

**Files:**

- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Modify: `lib/ui/pages/stats/widgets/ai_insight_view.dart`
- Modify: `lib/ui/pages/stats/stats_metrics.dart`
- Modify: `test/ui/pages/stats/pie_chart_view_test.dart`
- Modify: `test/ui/pages/stats/widgets/ai_insight_view_test.dart`
- Modify: `test/ui/pages/stats/stats_metrics_test.dart`

**Protected user changes:** retain the existing clipped-record constructor change and its newly added tests in `stats_metrics.dart` and `stats_metrics_test.dart`.

- [ ] **Step 1: Add failing stable-selection, zero-minute and calendar-month tests**

```dart
testWidgets('clears selected category when next range omits it', (tester) async {
  await tester.pumpWidget(buildPie(records: workAndReadRecords));
  await tester.tap(find.byType(PieChart));
  await tester.pump();
  await tester.pumpWidget(buildPie(records: workOnlyRecords));
  expect(tester.takeException(), isNull);
});

testWidgets('shows local AI suggestions for sub-minute records', (tester) async {
  final record = TimeRecord(
    id: 'short',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 12, 9),
    endTime: DateTime(2026, 7, 12, 9, 0, 30),
  );
  await tester.pumpWidget(buildAiInsight(records: [record]));
  expect(tester.takeException(), isNull);
});

test('month previous total uses previous calendar month', () {
  final metrics = StatsMetrics.forRange(
    [
      TimeRecord(
        id: 'february',
        categoryId: 'work',
        startTime: DateTime(2026, 2, 15, 9),
        endTime: DateTime(2026, 2, 15, 10),
      ),
    ],
    StatsRange.month,
    DateTime(2026, 3, 15),
  );
  expect(metrics.previousTotal, const Duration(hours: 1));
});
```

- [ ] **Step 2: Run stats tests and verify failure**

Run: `flutter test test/ui/pages/stats/pie_chart_view_test.dart test/ui/pages/stats/widgets/ai_insight_view_test.dart test/ui/pages/stats/stats_metrics_test.dart`

Expected: selected index can be stale, local suggestion divides by zero, and March comparison includes January dates.

- [ ] **Step 3: Implement stable category selection and safe metric calculations**

Replace `_selectedIndex` with `String? _selectedCategoryId`; derive the selected item only after finding its current index. Guard local-suggestion percentage when `total <= 0`. Build previous month range with `DateTime(now.year, now.month - 1)` and `DateTime(now.year, now.month)`; retain day/week duration-based ranges.

- [ ] **Step 4: Run focused stats tests**

Run: `flutter test test/ui/pages/stats/pie_chart_view_test.dart test/ui/pages/stats/widgets/ai_insight_view_test.dart test/ui/pages/stats/stats_metrics_test.dart`

Expected: PASS.

## Task 7: 同步最小文档并执行全量验证

**Files:**

- Modify: `design-demos/mytime-prototype.html`
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-07-12-data-integrity-foundation-design.md`

- [ ] **Step 1: Update the prototype's timer confirmation behavior**

Represent a fixed stop timestamp in the prototype confirmation state and add explicit save/discard actions. The prototype must not derive the saved end time from a later render time.

- [ ] **Step 2: Update Changelog**

Under `[Unreleased]`, document pending-confirmation recovery, fixed stop timestamps, idempotent record completion, category-driven record refresh, cross-midnight timeline clipping and statistics boundary fixes.

- [ ] **Step 3: Re-read the design spec and align final behavior**

Confirm the implemented session keys, failure copy and discard interaction match the design. Amend only factual differences discovered during implementation.

- [ ] **Step 4: Run format verification**

Run: `dart format --output=none --set-exit-if-changed lib test`

Expected: exit 0. If pre-existing formatting remains outside touched files, run `dart format` in a separate user-approved formatting change before claiming this gate passes.

- [ ] **Step 5: Run static analysis and all tests**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: all tests pass with zero failures.

- [ ] **Step 6: Verify protected files and report worktree state**

Run: `git diff -- ios/Runner.xcodeproj/project.pbxproj ios/Runner.xcworkspace/contents.xcworkspacedata lib/ui/pages/stats/stats_metrics.dart test/ui/pages/stats/stats_metrics_test.dart`

Expected: the two iOS files remain user-owned and the protected statistics diff is preserved except for user-approved test additions required by Task 6.

## Spec Coverage Review

| Spec requirement | Plan task |
|---|---|
| Pending timer session and fixed stop time | Tasks 2 and 3 |
| Failure/retry/discard behavior | Task 3 |
| Model and Repository validation | Task 1 |
| Category deletion refresh | Task 4 |
| Cross-midnight clipping | Task 5 |
| Pie/AI/month statistics stability | Task 6 |
| Regression tests and documentation | Tasks 1–7 |

## Plan Self-Review

- No dependency, Hive schema migration, iOS project edit or full architecture migration is included.
- The user-owned statistics and iOS diffs are explicitly protected.
- Every behavior change has a focused fail-first test and verification command.
- The plan intentionally excludes API Key security, import/export transactions and release signing so they can be designed and reviewed separately.
