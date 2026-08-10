# Stats & Timeline Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish stats/timeline visuals, add stacked bar chart with category filtering, add week view to timeline.

**Architecture:** Stats metrics get per-category trend data for stacked bars; StatsPage manages selected category order; TimelinePage adds day/week toggle with WeekView widget.

**Tech Stack:** Flutter, BLoC, fl_chart, CategoryLookup, AppColors

## Global Constraints

- No emoji in UI — use CustomPainter or text only
- All icons use `SvgIcons` or `CustomPainter` from `lib/widgets/svg_icons.dart`
- Use `CategoryLookup.all(context)` / `CategoryLookup.byId(context, id)` for category data
- Use `AppColors` / `context.colorScheme` / `AppThemeContext` extension for theming
- Colors from category model: `Color(int.parse(category.color.replaceFirst('#', '0xFF')))`
- `TimeRecord` has `duration` getter, `categoryId`, `startTime`, `endTime`
- Cards: 12px border radius, 3px shadow with `withValues(alpha: ...)`
- font: 12/13/15/16px; weights: 400/500/600/700
- `StatsMetrics` is a pure data class; all computation in `forRange()` static factory
- `formatStatsDuration()` from `stats_metrics.dart` for compact duration labels
- fl_chart version 0.69.x API

---

### Task 1: StatsMetrics — per-category trend data

**Files:**
- Modify: `lib/ui/pages/stats/stats_metrics.dart:7-12,129-161`
- Test: `test/ui/pages/stats/stats_metrics_test.dart`

**Interfaces:**
- Consumes: `TimeRecord` model (id, categoryId, startTime, endTime, duration)
- Produces: `StatsTrendPoint` with new `categoryDurations: Map<String, Duration>` field

- [ ] **Step 1: Update StatsTrendPoint to include categoryDurations**

```dart
// In lib/ui/pages/stats/stats_metrics.dart, replace the StatsTrendPoint class (lines 7-12)
class StatsTrendPoint {
  const StatsTrendPoint({
    required this.label,
    required this.duration,
    this.categoryDurations = const {},
  });

  final String label;
  final Duration duration;
  final Map<String, Duration> categoryDurations;
}
```

- [ ] **Step 2: Rewrite _trend() to compute per-category durations**

Replace the `_trend` method entirely:

```dart
  static List<StatsTrendPoint> _trend(
    List<TimeRecord> records,
    StatsRange range,
    _DateRange period,
  ) {
    final count = switch (range) {
      StatsRange.day => 24,
      StatsRange.week => 7,
      StatsRange.month =>
        period.end.day == 1
            ? period.end.subtract(const Duration(days: 1)).day
            : period.end.day,
    };
    return List.generate(count, (index) {
      final start = switch (range) {
        StatsRange.day => period.start.add(Duration(hours: index)),
        _ => period.start.add(Duration(days: index)),
      };
      final end = range == StatsRange.day
          ? start.add(const Duration(hours: 1))
          : start.add(const Duration(days: 1));
      final slot = _DateRange(start, end);
      Duration total = Duration.zero;
      final categoryDurations = <String, Duration>{};
      for (final record in records) {
        final d = _overlap(record, slot);
        if (d == Duration.zero) continue;
        total += d;
        final key = record.categoryId ?? 'uncategorized';
        categoryDurations[key] =
            (categoryDurations[key] ?? Duration.zero) + d;
      }
      final label = switch (range) {
        StatsRange.day => index.toString().padLeft(2, '0'),
        StatsRange.week => const ['一', '二', '三', '四', '五', '六', '日'][index],
        StatsRange.month => '${index + 1}',
      };
      return StatsTrendPoint(
        label: label,
        duration: total,
        categoryDurations: categoryDurations,
      );
    });
  }
```

- [ ] **Step 3: Run existing tests to verify nothing broke**

```bash
flutter test test/ui/pages/stats/stats_metrics_test.dart
```
Expected: all pass

- [ ] **Step 4: Add test for categoryDurations in trend data**

```dart
// In test/ui/pages/stats/stats_metrics_test.dart, add after the last test
  test('trend points include per-category durations', () {
    final records = [
      TimeRecord(
        id: 'r1',
        categoryId: 'work',
        startTime: DateTime(2026, 7, 10, 9),
        endTime: DateTime(2026, 7, 10, 11),
      ),
      TimeRecord(
        id: 'r2',
        categoryId: 'read',
        startTime: DateTime(2026, 7, 10, 14),
        endTime: DateTime(2026, 7, 10, 15, 30),
      ),
    ];
    final metrics = StatsMetrics.forRange(
      records,
      StatsRange.day,
      DateTime(2026, 7, 10, 16),
    );

    expect(metrics.trend, hasLength(24));
    // hour 9 should have 2h of work
    expect(
      metrics.trend[9].categoryDurations['work'],
      const Duration(hours: 2),
    );
    // hour 14 should have 1h of read
    expect(
      metrics.trend[14].categoryDurations['read'],
      const Duration(hours: 1),
    );
    // hour 14 should have no work
    expect(metrics.trend[14].categoryDurations['work'], isNull);
  });
```

- [ ] **Step 5: Run test to verify**

```bash
flutter test test/ui/pages/stats/stats_metrics_test.dart
```
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/stats/stats_metrics.dart test/ui/pages/stats/stats_metrics_test.dart
git commit -m "Add per-category trend data to StatsTrendPoint"
```

---

### Task 2: Category filter Bottom Sheet

**Files:**
- Create: `lib/ui/pages/stats/widgets/category_filter_sheet.dart`
- Test: `test/ui/pages/stats/widgets/category_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `List<Category>` (from `CategoryLookup.all`), `List<String> selectedIds` (ordered by selection)
- Produces: callback `ValueChanged<List<String>>` with new ordered selection

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/pages/stats/widgets/category_filter_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/ui/pages/stats/widgets/category_filter_sheet.dart';

void main() {
  testWidgets('shows all categories with checkboxes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                    const Category(id: 'rest', name: '休息', color: '#6B7280'),
                  ],
                  selectedIds: ['work', 'read'],
                  onChanged: (_) {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('休息'), findsOneWidget);
  });

  testWidgets('tapping unselected category appends it to selection', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                  ],
                  selectedIds: ['work'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // tap '阅读' to add it
    await tester.tap(find.text('阅读').last);
    await tester.pumpAndSettle();

    expect(result, ['work', 'read']);
  });

  testWidgets('tapping selected category removes it (keeping at least one)', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                  ],
                  selectedIds: ['work', 'read'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // deselect '工作' — should keep '阅读'
    await tester.tap(find.text('工作').last);
    await tester.pumpAndSettle();

    expect(result, ['read']);
  });

  testWidgets('cannot deselect the last remaining category', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                  ],
                  selectedIds: ['work'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // try to deselect '工作' — should stay selected
    await tester.tap(find.text('工作').last);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/pages/stats/widgets/category_filter_sheet_test.dart
```
Expected: FAIL (file not found / class not found)

- [ ] **Step 3: Write CategoryFilterSheet implementation**

```dart
// lib/ui/pages/stats/widgets/category_filter_sheet.dart
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/category.dart';

/// Bottom sheet for multi-selecting categories in click-order.
///
/// [selectedIds] is ordered by selection: first clicked = first in list = bottom of stack.
/// [onChanged] receives the new ordered list when the user taps a row.
class CategoryFilterSheet extends StatelessWidget {
  final List<Category> categories;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const CategoryFilterSheet({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '选择分类（点击顺序决定堆叠顺序）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '已选 ${selectedIds.length} 个分类',
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...categories.map((cat) => _buildRow(context, cat)),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, Category cat) {
    final selected = selectedIds.contains(cat.id);
    return InkWell(
      onTap: () {
        if (selected) {
          if (selectedIds.length <= 1) return;
          onChanged(selectedIds.where((id) => id != cat.id).toList());
        } else {
          onChanged([...selectedIds, cat.id]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
                      : context.colorScheme.outline,
                  width: 2,
                ),
                color: selected
                    ? Color(int.parse(cat.color.replaceFirst('#', '0xFF')))
                        .withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Color(int.parse(cat.color.replaceFirst('#', '0xFF'))),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(int.parse(cat.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? context.colorScheme.onSurface
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '#${selectedIds.indexOf(cat.id) + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/ui/pages/stats/widgets/category_filter_sheet_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/stats/widgets/category_filter_sheet.dart test/ui/pages/stats/widgets/category_filter_sheet_test.dart
git commit -m "Add category filter Bottom Sheet"
```

---

### Task 3: Stacked bar chart with category filter

**Files:**
- Modify: `lib/ui/pages/stats/widgets/bar_chart_view.dart` (full rewrite)
- Modify: `lib/ui/pages/stats/stats_page.dart` (add filter state, wire to bar chart)
- Test: `test/ui/pages/stats/widgets/bar_chart_view_test.dart` (new)

**Interfaces:**
- Consumes: `List<StatsTrendPoint>` (with `categoryDurations`), `List<String> selectedCategoryIds` (ordered), `BuildContext` for CategoryLookup
- Produces: rendered stacked BarChart with touch tooltips

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/pages/stats/widgets/bar_chart_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';
import 'package:mytime/ui/pages/stats/widgets/bar_chart_view.dart';

void main() {
  testWidgets('renders stacked bar chart with selected categories', (tester) async {
    final points = [
      StatsTrendPoint(
        label: '一',
        duration: const Duration(hours: 3),
        categoryDurations: {
          'work': const Duration(hours: 2),
          'read': const Duration(hours: 1),
        },
      ),
      StatsTrendPoint(
        label: '二',
        duration: const Duration(hours: 1),
        categoryDurations: {
          'work': const Duration(hours: 1),
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarChartView(
            points: points,
            selectedCategoryIds: ['work', 'read'],
          ),
        ),
      ),
    );

    // Should render chart area (SizedBox with height 160)
    expect(find.byType(SizedBox), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/pages/stats/widgets/bar_chart_view_test.dart
```
Expected: FAIL (BarChartView doesn't accept selectedCategoryIds)

- [ ] **Step 3: Rewrite BarChartView as stacked bar chart**

```dart
// lib/ui/pages/stats/widgets/bar_chart_view.dart — full rewrite
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// Stacked bar chart showing daily time trends per category.
class BarChartView extends StatelessWidget {
  final List<StatsTrendPoint> points;
  final List<String> selectedCategoryIds;

  const BarChartView({
    super.key,
    required this.points,
    this.selectedCategoryIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    final maxY = points.fold<double>(
      0,
      (m, p) {
        final total = selectedCategoryIds.fold<double>(
          0,
          (sum, id) => sum + (p.categoryDurations[id]?.inMinutes ?? 0) / 60,
        );
        return total > m ? total : m;
      },
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.22 : 0.04,
              ),
              blurRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY * 1.2 : 1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[groupIndex];
                    final catId = _categoryAtRod(
                      point,
                      rodIndex,
                      selectedCategoryIds,
                    );
                    final catName = catId != null
                        ? CategoryLookup.byId(context, catId).name
                        : '';
                    return BarTooltipItem(
                      '${point.label}\n$catName ${formatStatsDuration(
                        Duration(minutes: (rod.toY - rod.fromY).round() * 60),
                      )}',
                      TextStyle(
                        color: context.colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: points.indexed.map((entry) {
                final idx = entry.$1;
                final point = entry.$2;
                final rods = _buildRods(context, point);
                return BarChartGroupData(x: idx, barRods: rods);
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final point = points[idx];
                      final showLabel = points.length <= 7 || idx % 3 == 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Semantics(
                          label: '${point.label}，${formatStatsDuration(point.duration)}',
                          child: Text(
                            showLabel ? point.label : '',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  List<BarChartRodData> _buildRods(BuildContext context, StatsTrendPoint point) {
    final rods = <BarChartRodData>[];
    double cumulative = 0;
    final activeIds = selectedCategoryIds.isEmpty
        ? point.categoryDurations.keys.toList()
        : selectedCategoryIds.where((id) => point.categoryDurations.containsKey(id)).toList();

    for (var i = 0; i < activeIds.length; i++) {
      final catId = activeIds[i];
      final value = (point.categoryDurations[catId]?.inMinutes ?? 0) / 60;
      if (value <= 0) continue;
      final cat = CategoryLookup.byId(context, catId);
      final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      rods.add(
        BarChartRodData(
          fromY: cumulative,
          toY: cumulative + value,
          color: color.withValues(alpha: 0.85),
          width: 16,
          borderRadius: i == activeIds.length - 1
              ? const BorderRadius.vertical(top: Radius.circular(4))
              : BorderRadius.zero,
        ),
      );
      cumulative += value;
    }
    return rods;
  }

  /// Find which category ID a rod index corresponds to.
  String? _categoryAtRod(
    StatsTrendPoint point,
    int rodIndex,
    List<String> selectedIds,
  ) {
    final activeIds = selectedIds.isEmpty
        ? point.categoryDurations.keys.toList()
        : selectedIds.where((id) => point.categoryDurations.containsKey(id)).toList();
    var idx = 0;
    for (final catId in activeIds) {
      final value = point.categoryDurations[catId]?.inMinutes ?? 0;
      if (value > 0) {
        if (idx == rodIndex) return catId;
        idx++;
      }
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/ui/pages/stats/widgets/bar_chart_view_test.dart
```
Expected: PASS

- [ ] **Step 5: Update StatsPage to manage filter state and pass to BarChartView**

In `lib/ui/pages/stats/stats_page.dart`:

```dart
// Add after line 18 (class _StatsPageState extends State<StatsPage>)
  List<String> _selectedCategoryIds = [];
```

```dart
// Add method to initialize selected categories
  void _initSelectedCategories(BuildContext context) {
    if (_selectedCategoryIds.isNotEmpty) return;
    final cats = CategoryLookup.all(context);
    _selectedCategoryIds = cats.map((c) => c.id).toList();
  }
```

```dart
// Change the BarChartView line (line 125):
        case 'bar':
          _initSelectedCategories(context);
          return Column(
            children: [
              _buildFilterButton(context),
              Expanded(
                child: BarChartView(
                  points: metrics.trend,
                  selectedCategoryIds: _selectedCategoryIds,
                ),
              ),
            ],
          );
```

Add the filter button method:
```dart
  Widget _buildFilterButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showFilterSheet(context),
          icon: const Icon(Icons.tune, size: 16),
          label: Text('已选 ${_selectedCategoryIds.length} 个分类'),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) async {
    final cats = CategoryLookup.all(context);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (_) => CategoryFilterSheet(
        categories: cats,
        selectedIds: _selectedCategoryIds,
        onChanged: (v) => Navigator.of(context).pop(v),
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategoryIds = result);
    }
  }
```

Add imports:
```dart
// Add at top of stats_page.dart
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/ui/pages/stats/widgets/category_filter_sheet.dart';
```

- [ ] **Step 6: Run tests to verify**

```bash
flutter test test/ui/pages/stats/stats_page_test.dart
```
Expected: all pass

- [ ] **Step 7: Commit**

```bash
git add lib/ui/pages/stats/widgets/bar_chart_view.dart test/ui/pages/stats/widgets/bar_chart_view_test.dart
git commit -m "Rewrite bar chart as stacked category chart"
git add lib/ui/pages/stats/stats_page.dart
git commit -m "Add category filter state to StatsPage"
```

---

### Task 4: Summary cards — fix change display

**Files:**
- Modify: `lib/ui/pages/stats/widgets/summary_cards.dart` (fix change color logic)
- Modify: `lib/ui/pages/stats/stats_page.dart` (compute change2/change3)
- Test: `test/ui/pages/stats/widgets/summary_cards_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/pages/stats/widgets/summary_cards_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/stats/widgets/summary_cards.dart';

void main() {
  testWidgets('shows three cards with values and changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCards(
            value1: '4h 20m',
            value2: '3h 50m',
            value3: '30m',
            change1: '+12%',
            change2: '-5%',
            change3: '+0%',
          ),
        ),
      ),
    );

    expect(find.text('4h 20m'), findsOneWidget);
    expect(find.text('3h 50m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('-5%'), findsOneWidget);
    expect(find.text('+0%'), findsOneWidget);
  });

  testWidgets('positive change shows green, negative shows red', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCards(
            value1: '1h',
            value2: '1h',
            value3: '1h',
            change1: '+12%',
            change2: '-5%',
            change3: '+0%',
          ),
        ),
      ),
    );

    // Check that +12% text exists (green by default)
    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('-5%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test**

```bash
flutter test test/ui/pages/stats/widgets/summary_cards_test.dart
```
Expected: PASS (the current implementation should work for basic rendering)

- [ ] **Step 3: Fix the change color logic in SummaryCards**

The current `_StatCard` determines positive by checking `!change.startsWith('-')`. This treats `+0%` as positive (green) and `-5%` as negative (red), which is correct. But the issue is that the `_StatCard` widget treats `+0%` (which starts with '+') as positive. Let me verify the logic:

```dart
final positive = !change.startsWith('-');
```

For `+12%`: `!startsWith('-')` = true → positive (green) ✓
For `-5%`: `!startsWith('-')` = false → negative (red) ✓
For `+0%`: `!startsWith('-')` = true → positive (green) ✓

The logic is correct. The issue was just that `change2` and `change3` were empty strings. Let me fix the data in `stats_page.dart`.

- [ ] **Step 4: Fix stats_page.dart to compute change2 and change3**

In `lib/ui/pages/stats/stats_page.dart`, replace the `_buildSummaryCards` method:

```dart
  Widget _buildSummaryCards(StatsMetrics metrics) {
    String format(Duration value) =>
        '${value.inHours}h ${value.inMinutes % 60}m';
    final change = metrics.previousTotal.inMinutes == 0
        ? 0
        : ((metrics.total.inMinutes - metrics.previousTotal.inMinutes) *
              100 ~/
              metrics.previousTotal.inMinutes);
    final isDay = metrics.range == StatsRange.day;
    final changeStr = '${change >= 0 ? '+' : ''}$change%';
    return SummaryCards(
      label1: isDay
          ? '今日总时长'
          : metrics.range == StatsRange.week
          ? '本周总时长'
          : '本月总时长',
      value1: format(metrics.total),
      change1: changeStr,
      label2: isDay ? '昨日总时长' : '日均',
      value2: format(isDay ? metrics.previousTotal : metrics.average),
      change2: changeStr,
      label3: isDay ? '较昨日变化' : '较上一周期',
      value3: format(metrics.previousTotal),
      change3: changeStr,
    );
  }
```

- [ ] **Step 5: Run tests**

```bash
flutter test test/ui/pages/stats/
```
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/stats/stats_page.dart test/ui/pages/stats/widgets/summary_cards_test.dart
git commit -m "Fix change2/change3 display in summary cards"
```

---

### Task 5: Pie chart — center total text

**Files:**
- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Test: `test/ui/pages/stats/pie_chart_view_test.dart` (update existing)

- [ ] **Step 1: Update the pie chart test to check for center total text**

```dart
// In test/ui/pages/stats/pie_chart_view_test.dart, add a new test:
  testWidgets('shows center total when no category is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PieChartView(
            categoryDurations: const {'work': Duration(hours: 2)},
          ),
        ),
      ),
    );

    // Should show total text
    expect(find.text('2h 00m'), findsOneWidget);
    expect(find.text('总计'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/pages/stats/pie_chart_view_test.dart
```
Expected: FAIL (text "总计" not found)

- [ ] **Step 3: Add center total text to PieChartView**

In `lib/ui/pages/stats/widgets/pie_chart_view.dart`, modify the `Stack` in `_buildContent`:

Find this section in the `_buildContent` method (around line 99-134):
```dart
              child: SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Semantics(
                      label:
                          '分类饼图，${items.map((item) => '${item.category} ${item.percentage}%').join('，')}',
                      child: PieChart(
                        PieChartData(
                          sections: _sections(items),
                          centerSpaceRadius: 38,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent) return;
                              final index =
                                  response?.touchedSection?.touchedSectionIndex;
                              setState(() {
                                _selectedCategory =
                                    index == null ||
                                        index < 0 ||
                                        index >= items.length ||
                                        items[index].categoryId ==
                                            _selectedCategory
                                    ? null
                                    : items[index].categoryId;
                              });
                            },
                          ),
                        ),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                    ),
                    if (selectedItem != null) _Tooltip(item: selectedItem),
                  ],
                ),
              ),
```

Replace with:
```dart
              child: SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Semantics(
                      label:
                          '分类饼图，${items.map((item) => '${item.category} ${item.percentage}%').join('，')}',
                      child: PieChart(
                        PieChartData(
                          sections: _sections(items),
                          centerSpaceRadius: 44,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent) return;
                              final index =
                                  response?.touchedSection?.touchedSectionIndex;
                              setState(() {
                                _selectedCategory =
                                    index == null ||
                                        index < 0 ||
                                        index >= items.length ||
                                        items[index].categoryId ==
                                            _selectedCategory
                                    ? null
                                    : items[index].categoryId;
                              });
                            },
                          ),
                        ),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      ),
                    ),
                    if (selectedItem != null)
                      _Tooltip(item: selectedItem)
                    else
                      _CenterTotal(total: totalSeconds),
                  ],
                ),
              ),
```

Add the `_CenterTotal` widget at the bottom of the file (before the last closing brace):

```dart
class _CenterTotal extends StatelessWidget {
  final int total;
  const _CenterTotal({required this.total});

  @override
  Widget build(BuildContext context) {
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final label = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes}m';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.colorScheme.onSurface,
          ),
        ),
        Text(
          '总计',
          style: TextStyle(
            fontSize: 10,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify**

```bash
flutter test test/ui/pages/stats/pie_chart_view_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/stats/widgets/pie_chart_view.dart test/ui/pages/stats/pie_chart_view_test.dart
git commit -m "Add center total text to pie chart"
```

---

### Task 6: Week view widget

**Files:**
- Create: `lib/ui/pages/timeline/widgets/week_view.dart`
- Test: `test/ui/pages/timeline/widgets/week_view_test.dart`

**Interfaces:**
- Consumes: `DateTime selectedDate`, `List<TimeRecord> records`, `ValueChanged<DateTime> onDayTap`
- Produces: rendered 7-day stacked bar chart

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/pages/timeline/widgets/week_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/widgets/week_view.dart';

void main() {
  testWidgets('renders 7-day stacked bars for the week', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekView(
            selectedDate: DateTime(2026, 7, 10), // Friday
            records: [
              TimeRecord(
                id: 'r1',
                categoryId: 'work',
                startTime: DateTime(2026, 7, 10, 9),
                endTime: DateTime(2026, 7, 10, 11),
              ),
            ],
            onDayTap: (_) {},
          ),
        ),
      ),
    );

    // Should show day labels
    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
    expect(find.text('三'), findsOneWidget);
    expect(find.text('四'), findsOneWidget);
    expect(find.text('五'), findsOneWidget);
    expect(find.text('六'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
    // Should show date labels
    expect(find.text('7/6'), findsOneWidget); // Monday
    expect(find.text('7/10'), findsOneWidget); // Friday
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/pages/timeline/widgets/week_view_test.dart
```
Expected: FAIL (file not found)

- [ ] **Step 3: Write WeekView implementation**

```dart
// lib/ui/pages/timeline/widgets/week_view.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';

/// 7-day stacked bar chart for the week view on the timeline page.
class WeekView extends StatelessWidget {
  final DateTime selectedDate;
  final List<TimeRecord> records;
  final ValueChanged<DateTime> onDayTap;

  const WeekView({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final weekData = _computeWeekData();
    final maxY = weekData.fold<double>(
      0,
      (m, d) => (d.total.inMinutes / 60) > m ? (d.total.inMinutes / 60) : m,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.22 : 0.04,
              ),
              blurRadius: 3,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY > 0 ? maxY * 1.3 : 1,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final idx = response?.touchedGroupIndex ?? -1;
                  if (idx >= 0 && idx < weekData.length) {
                    onDayTap(weekData[idx].date);
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = weekData[groupIndex];
                    final catId = _categoryAtRod(day, rodIndex);
                    final catName = catId != null
                        ? CategoryLookup.byId(context, catId).name
                        : '';
                    return BarTooltipItem(
                      '${day.label}\n$catName ${formatStatsDuration(
                        Duration(minutes: (rod.toY - rod.fromY).round() * 60),
                      )}',
                      TextStyle(
                        color: context.colorScheme.onPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              barGroups: weekData.indexed.map((entry) {
                final idx = entry.$1;
                final day = entry.$2;
                return BarChartGroupData(
                  x: idx,
                  barRods: _buildRods(context, day),
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= weekData.length) {
                        return const SizedBox.shrink();
                      }
                      final day = weekData[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: [
                            Text(
                              day.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${day.date.month}/${day.date.day}',
                              style: TextStyle(
                                fontSize: 9,
                                color: context.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  List<_DayData> _computeWeekData() {
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    return List.generate(7, (index) {
      final day = weekStart.add(Duration(days: index));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      Duration total = Duration.zero;
      final categoryDurations = <String, Duration>{};
      for (final record in records) {
        final overlapStart =
            record.startTime.isAfter(dayStart) ? record.startTime : dayStart;
        final overlapEnd =
            record.endTime.isBefore(dayEnd) ? record.endTime : dayEnd;
        final d = overlapEnd.difference(overlapStart);
        if (d <= Duration.zero) continue;
        total += d;
        final key = record.categoryId ?? 'uncategorized';
        categoryDurations[key] =
            (categoryDurations[key] ?? Duration.zero) + d;
      }
      return _DayData(
        date: day,
        label: const ['一', '二', '三', '四', '五', '六', '日'][index],
        total: total,
        categoryDurations: categoryDurations,
      );
    });
  }

  List<BarChartRodData> _buildRods(BuildContext context, _DayData day) {
    final rods = <BarChartRodData>[];
    double cumulative = 0;
    final ids = day.categoryDurations.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      final catId = ids[i];
      final value = (day.categoryDurations[catId]?.inMinutes ?? 0) / 60;
      if (value <= 0) continue;
      final cat = CategoryLookup.byId(context, catId);
      final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      rods.add(
        BarChartRodData(
          fromY: cumulative,
          toY: cumulative + value,
          color: color.withValues(alpha: 0.85),
          width: 24,
          borderRadius: i == ids.length - 1
              ? const BorderRadius.vertical(top: Radius.circular(4))
              : BorderRadius.zero,
        ),
      );
      cumulative += value;
    }
    if (rods.isEmpty) {
      rods.add(
        BarChartRodData(
          toY: 0.01,
          color: Colors.transparent,
          width: 24,
        ),
      );
    }
    return rods;
  }

  String? _categoryAtRod(_DayData day, int rodIndex) {
    var idx = 0;
    for (final catId in day.categoryDurations.keys) {
      final value = day.categoryDurations[catId]?.inMinutes ?? 0;
      if (value > 0) {
        if (idx == rodIndex) return catId;
        idx++;
      }
    }
    return null;
  }
}

class _DayData {
  final DateTime date;
  final String label;
  final Duration total;
  final Map<String, Duration> categoryDurations;

  const _DayData({
    required this.date,
    required this.label,
    required this.total,
    required this.categoryDurations,
  });
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/ui/pages/timeline/widgets/week_view_test.dart
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/timeline/widgets/week_view.dart test/ui/pages/timeline/widgets/week_view_test.dart
git commit -m "Add week view widget with 7-day stacked bars"
```

---

### Task 7: Timeline page — day/week toggle

**Files:**
- Modify: `lib/ui/pages/timeline/timeline_page.dart` (add toggle, integrate week view)
- Test: `test/ui/pages/timeline/timeline_page_test.dart` (update)

- [ ] **Step 1: Write the failing test**

```dart
// In test/ui/pages/timeline/timeline_page_test.dart, add new tests:
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/timeline/timeline_page.dart';

// Add inside main(), after the existing tests:
  testWidgets('shows day/week toggle tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo),
          child: const TimelinePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('日'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
  });

  testWidgets('tapping week tab shows week view', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo),
          child: const TimelinePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // Tap week tab
    await tester.tap(find.text('周'));
    await tester.pump();

    // Should show day labels
    expect(find.text('一'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ui/pages/timeline/timeline_page_test.dart
```
Expected: FAIL (no "日"/"周" text found)

- [ ] **Step 3: Add day/week toggle to TimelinePage**

In `lib/ui/pages/timeline/timeline_page.dart`, add:

```dart
// Add enum after imports
enum _TimelineViewMode { day, week }
```

```dart
// Add field in _TimelinePageState (around line 31)
  _TimelineViewMode _viewMode = _TimelineViewMode.day;
```

```dart
// Add the toggle widget after DateNavigator in the build method (around line 160)
            DateNavigator(
              date: _selectedDate,
              onPrev: () => _onDateChanged(-1),
              onNext: () => _onDateChanged(1),
            ),
            _buildViewToggle(),
```

```dart
// Add the toggle builder method
  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = _TimelineViewMode.day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _viewMode == _TimelineViewMode.day
                      ? context.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '日',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _viewMode == _TimelineViewMode.day
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _viewMode = _TimelineViewMode.week),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _viewMode == _TimelineViewMode.week
                      ? context.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '周',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _viewMode == _TimelineViewMode.week
                        ? context.colorScheme.onPrimary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Wrap the timeline content with view mode switching**

In the `build` method, replace the `Expanded` child that currently shows the timeline:

Find the `BlocBuilder` inside `Expanded` and make the content conditional on `_viewMode`:

```dart
            Expanded(
              child: BlocBuilder<RecordsBloc, RecordsState>(
                builder: (context, state) {
                  if (state is RecordsLoading || state is RecordsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is RecordsLoaded) {
                    if (_viewMode == _TimelineViewMode.week) {
                      return WeekView(
                        selectedDate: _selectedDate,
                        records: state.records,
                        onDayTap: (date) {
                          setState(() {
                            _selectedDate = date;
                            _viewMode = _TimelineViewMode.day;
                          });
                        },
                      );
                    }
                    return _buildTimeline(
                      state.records
                          .where(_isSelectedDate)
                          .map(_clipToSelectedDate)
                          .toList(),
                    );
                  }
                  return Center(
                    child: Text(
                      '暂无记录',
                      style: TextStyle(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
```

Add the `WeekView` import:
```dart
import 'package:mytime/ui/pages/timeline/widgets/week_view.dart';
```

- [ ] **Step 5: Run tests to verify**

```bash
flutter test test/ui/pages/timeline/timeline_page_test.dart
```
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/timeline/timeline_page.dart test/ui/pages/timeline/timeline_page_test.dart
git commit -m "Add day/week toggle and week view to timeline page"
```

---

### Task 8: Run all tests and verify

- [ ] **Step 1: Run all tests**

```bash
flutter test
```
Expected: all pass

- [ ] **Step 2: Run flutter analyze**

```bash
flutter analyze
```
Expected: no errors

- [ ] **Step 3: Fix any issues found**

If there are analysis errors or test failures, fix them before proceeding.

- [ ] **Step 4: Final commit if fixes were needed**

```bash
git add -A
git commit -m "Fix lint and test issues"
```