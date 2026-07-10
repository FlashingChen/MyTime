# 日时间线与双指缩放 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将时间线改为全天日视图，并提供不干扰滚动的双指捏合缩放和正确的相邻记录排版。

**Architecture:** 新增纯 Dart 布局器输出每张记录的位置与列数；页面保留数据加载和渲染职责。缩放更新小时高度，并用 ScrollController 使双指焦点对应的时间保持在原位置。

**Tech Stack:** Flutter、flutter_bloc、Hive、flutter_test。

## Global Constraints

- 不新增依赖；使用现有 BLoC、Hive 和 Flutter SDK。
- 保持原型配色、简体中文文案、12px 卡片圆角；图标仅用 SVG 或 CustomPainter。
- 每个交互元素至少 44×44，必要处添加 Semantics。
- 完成后更新原型、README、CHANGELOG 的 [Unreleased]，运行 flutter analyze 与 flutter test。

---

### Task 1: 纯 Dart 的日时间线布局器

**Files:**
- Create: `lib/ui/pages/timeline/timeline_layout.dart`
- Create: `test/ui/pages/timeline/timeline_layout_test.dart`

**Interfaces:**
- Produces: `TimelineCardLayout(record, top, height, column, columnCount)`
- Produces: `TimelineLayout.calculate(List<TimeRecord> records, {required double hourHeight, required double minCardHeight})`

- [ ] **Step 1: Write the failing tests**

```dart
test('visually adjacent short records use two columns', () {
  final layouts = TimelineLayout.calculate([
    record(9, 0, 9, 10), record(9, 15, 9, 45),
  ], hourHeight: 60, minCardHeight: 24);
  expect(layouts.map((item) => item.column), [0, 1]);
  expect(layouts.map((item) => item.columnCount), [2, 2]);
});

test('record after an overlap group returns to one column', () {
  final layouts = TimelineLayout.calculate([
    record(9, 0, 10, 0), record(9, 30, 10, 30), record(11, 0, 12, 0),
  ], hourHeight: 60, minCardHeight: 24);
  expect(layouts[2].columnCount, 1);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/pages/timeline/timeline_layout_test.dart`  
Expected: FAIL because `TimelineLayout` is undefined.

- [ ] **Step 3: Implement the calculator**

Create visual intervals from minutes since midnight. Set each end to `max(actualEnd, top + minCardHeight)`. Sort by visual start/end, split a group when the next start is at or after the group's maximum visual end, and within each group assign the first column whose visual end is no later than the next start. Set every member's `columnCount` to the group's maximum column count.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/ui/pages/timeline/timeline_layout_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/timeline/timeline_layout.dart test/ui/pages/timeline/timeline_layout_test.dart
git commit -m "Add timeline layout calculator"
```

### Task 2: 全天日视图和双指缩放

**Files:**
- Modify: `lib/ui/pages/timeline/timeline_page.dart`
- Modify: `test/ui/pages/timeline/timeline_page_test.dart`

**Interfaces:**
- Consumes: `TimelineLayout.calculate`
- Produces: one 00:00–24:00 timeline with `hourHeight` bounded to `30.0..120.0`

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('renders 00:00 through 24:00', (tester) async {
  await pumpTimeline(tester, records: [record(0, 5, 0, 20), record(23, 30, 23, 50)]);
  expect(find.text('00:00'), findsOneWidget);
  await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -2000));
  await tester.pumpAndSettle();
  expect(find.text('24:00'), findsOneWidget);
});

testWidgets('double tap restores default scale feedback', (tester) async {
  await pumpTimeline(tester);
  await tester.tapAt(const Offset(120, 300));
  await tester.tapAt(const Offset(120, 300));
  await tester.pumpAndSettle();
  expect(find.text('100%'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/pages/timeline/timeline_page_test.dart`  
Expected: FAIL because the axis ends at 22:00 and the day/week controls remain.

- [ ] **Step 3: Implement day-only rendering**

Remove `_viewMode` and `_ViewToggle`. Change initialization to `LoadRecords()` and filter the already-loaded all-record list by `_selectedDate` in `TimelinePage`; date navigation only calls `setState`, never dispatches `LoadRecordsByDate`. This prevents the shared `RecordsBloc` from replacing the stats/home/record-management data with a one-day subset. Render 25 labels from 00:00 through 24:00 and a `24 * _hourHeight` canvas. Replace inline assignment logic with layouts from Task 1.

- [ ] **Step 4: Implement pointer-safe pinch handling**

Wrap the scroll area in `Listener`, maintain active pointer positions, and calculate scale only while two pointers exist. On every scale update clamp the new hour height and preserve focal time:

```dart
final contentY = _scrollController.offset + localFocalY;
final ratio = newHourHeight / oldHourHeight;
setState(() => _hourHeight = newHourHeight);
_scrollController.jumpTo(
  ((contentY * ratio) - localFocalY)
      .clamp(0.0, _scrollController.position.maxScrollExtent),
);
```

Reset the two-pointer baseline after each update. Add double-tap restoration to 60 px/hour and a transient `Semantics(liveRegion: true, child: Text('100%'))` label.

- [ ] **Step 5: Run focused tests**

Run: `flutter test test/ui/pages/timeline`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/timeline test/ui/pages/timeline
git commit -m "Fix daily timeline range and zoom"
```

### Task 3: Documentation and final verification

**Files:**
- Modify: `design-demos/mytime-prototype.html`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-07-09-mytime-design.md`

- [ ] **Step 1: Update all day/week copy**

Remove the view toggle from the prototype, describe a 00:00–24:00 pinch-zoom day timeline, and replace every “日 / 周时间线视图” claim with “可缩放的全天日时间线”.

- [ ] **Step 2: Record the behavior change**

Add an Unreleased Changed entry covering removal of week view, full-day rendering, and visual-interval collision handling.

- [ ] **Step 3: Run verification**

Run: `flutter analyze && flutter test`  
Expected: both commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add design-demos/mytime-prototype.html README.md CHANGELOG.md docs/superpowers/specs/2026-07-09-mytime-design.md
git commit -m "Document daily timeline behavior"
```
