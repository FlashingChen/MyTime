# 统计页分析改进 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让本日、本周、本月统计采用正确的区间与趋势粒度，并增强摘要、占比和建议。

**Architecture:** 新增纯 Dart 统计计算器，统一计算半开区间内的相交时长、摘要、分类与趋势点；页面和图表只消费指标。

**Tech Stack:** Flutter、flutter_bloc、fl_chart、flutter_test。

## Global Constraints

- 不新增依赖；保留现有 BLoC 与 fl_chart。
- 保持深色、靛紫渐变和白色 12px 圆角卡片，文案为简体中文。
- 聚合不放入 Widget build；使用纯工具文件。
- 完成后更新原型和 CHANGELOG，运行 flutter analyze 与 flutter test。

---

### Task 1: 统计区间和指标工具

**Files:**
- Create: `lib/ui/pages/stats/stats_metrics.dart`
- Create: `test/ui/pages/stats/stats_metrics_test.dart`

**Interfaces:**
- Produces: `enum StatsRange { day, week, month }`
- Produces: `StatsMetrics.forRange(records, range, now)`
- Produces: `StatsTrendPoint(label, duration)`

- [ ] **Step 1: Write failing tests**

```dart
test('counts only the overlap at a day boundary', () {
  final metrics = StatsMetrics.forRange(
    [record(DateTime(2026, 7, 9, 23), DateTime(2026, 7, 10, 1))],
    StatsRange.day,
    DateTime(2026, 7, 10, 12),
  );
  expect(metrics.total, const Duration(hours: 1));
});

test('week has seven daily buckets and month has calendar-day buckets', () {
  expect(StatsMetrics.forRange([], StatsRange.week, DateTime(2026, 7, 10)).trend, hasLength(7));
  expect(StatsMetrics.forRange([], StatsRange.month, DateTime(2026, 7, 10)).trend, hasLength(31));
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/ui/pages/stats/stats_metrics_test.dart`  
Expected: FAIL because `StatsMetrics` is undefined.

- [ ] **Step 3: Implement clipped accumulation**

Use half-open periods `[start, end)`. For each record use:

```dart
final clippedStart = record.startTime.isAfter(start) ? record.startTime : start;
final clippedEnd = record.endTime.isBefore(end) ? record.endTime : end;
final duration = clippedEnd.isAfter(clippedStart)
    ? clippedEnd.difference(clippedStart)
    : Duration.zero;
```

Build 24 hourly buckets for day, seven midnight buckets for week, and one bucket per calendar date for month. Aggregate categories using the clipped duration.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/ui/pages/stats/stats_metrics_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/stats/stats_metrics.dart test/ui/pages/stats/stats_metrics_test.dart
git commit -m "Add statistics range metrics"
```

### Task 2: Bind the page and chart widgets to metrics

**Files:**
- Modify: `lib/ui/pages/stats/stats_page.dart`
- Modify: `lib/ui/pages/stats/widgets/summary_cards.dart`
- Modify: `lib/ui/pages/stats/widgets/bar_chart_view.dart`
- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Modify: `lib/ui/pages/stats/widgets/ai_insight_view.dart`
- Modify: `test/ui/pages/stats/stats_page_test.dart`

**Interfaces:**
- Consumes: `StatsMetrics.forRange`
- Changes: `BarChartView` consumes ordered trend points, not weekday aggregation.
- Changes: `PieChartView` exposes selected-category touch state.

- [ ] **Step 1: Write failing range-switch test**

```dart
testWidgets('changes trend granularity with selected range', (tester) async {
  await pumpStats(tester, records: monthRecords);
  await tester.tap(find.text('本日'));
  await tester.pumpAndSettle();
  expect(find.text('00'), findsOneWidget);
  await tester.tap(find.text('本月'));
  await tester.pumpAndSettle();
  expect(find.text('31'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/ui/pages/stats/stats_page_test.dart`  
Expected: FAIL because the current chart always labels weekdays.

- [ ] **Step 3: Replace page-local filters**

Construct metrics once for a `RecordsLoaded` state. Remove all `r.startTime.isAfter(...)` range switches. Pass metrics to all tabs and render cards as: day = 今日总时长 / 昨日总时长 / 较昨日变化; week and month = 总时长 / 日均 / 较上一周期变化.

- [ ] **Step 4: Implement component improvements**

Show the total duration in the pie centre. Sort legend rows by duration and show duration, percentage and record count. Use `PieTouchData` to highlight a selected category. Pass `periodLabel` into `AiInsightView` and remove its fixed “本周总结” text.

- [ ] **Step 5: Run focused tests**

Run: `flutter test test/ui/pages/stats`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/stats test/ui/pages/stats
git commit -m "Improve statistics range analysis"
```

### Task 3: Prototype and verification

**Files:**
- Modify: `design-demos/mytime-prototype.html`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update the prototype**

Make summary labels range-aware; display total duration in the pie centre; document day/hour, week/day and month/date trend granularities.

- [ ] **Step 2: Update changelog**

Add Unreleased entries for corrected period aggregation, range-aware trends, and enhanced pie/AI display.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test`  
Expected: both commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add design-demos/mytime-prototype.html CHANGELOG.md
git commit -m "Document improved statistics"
```

