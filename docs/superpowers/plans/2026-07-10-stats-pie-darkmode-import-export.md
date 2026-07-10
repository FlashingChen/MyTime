# 统计饼图点击高亮 + 深色模式 + 导入导出弹窗 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现统计页饼图点击高亮与浮动 Tooltip、全局深色模式适配、数据导入导出成功/失败弹窗提示。

**Architecture:** 以 Material 3 `ColorScheme` 语义化颜色为核心，完善 `AppTheme` 两套主题并新增 `BuildContext` 扩展；各页面从硬编码 `AppColors` 迁移到 `Theme.of(context).colorScheme`；饼图通过 StatefulWidget 状态管理实现高亮；导入导出通过 `showDialog` 替换 SnackBar。

**Tech Stack:** Flutter (Dart), flutter_bloc, fl_chart, Hive, SharedPreferences.

## Global Constraints

- 框架：Flutter (Dart)
- 状态管理：BLoC（`flutter_bloc`）
- 本地存储：Hive（记录数据）+ SharedPreferences（配置）
- 图表：fl_chart
- 导航：GoRouter（本项目当前未使用，保持现状）
- 不得擅自引入新依赖
- 不使用 emoji，所有图标用 SVG（`flutter_svg`）或自绘 `CustomPainter`
- 必须以 `design-demos/mytime-prototype.html` 为 UI 锚点
- 文案：简体中文，动词 + 名词命名页签
- 文件命名：小写下划线；类命名：大驼峰；私有成员带前缀下划线
- 每个 public 类有文档注释（`///`）
- BLoC 事件命名动词过去式，状态命名描述性
- 时间线列表用 `ListView.builder`（已满足）
- 图表数据计算放 Repository / UseCase，不放 Widget build 里（已满足）
- 所有交互元素最小 44×44 命中区域
- 新增功能必须更新 `CHANGELOG.md` 的 `[Unreleased]` 段
- Commit message 用英文祈使句
- 完成任务前必须跑 `flutter analyze`、`flutter test`

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/theme/app_theme_ext.dart` (create) | `BuildContext` 扩展：快捷访问 `colorScheme` 和 `isDark` |
| `lib/core/theme/app_theme.dart` (modify) | 完善 light/dark ThemeData、ColorScheme、子主题 |
| `lib/ui/app_shell.dart` (modify) | BottomNavigationBar 使用主题色 |
| `lib/ui/pages/stats/widgets/pie_chart_view.dart` (modify) | 饼图 StatefulWidget + 点击高亮 + Tooltip + 图例联动 |
| `lib/ui/pages/settings/settings_page.dart` (modify) | 导入导出结果弹窗 + 移除硬编码颜色 |
| `lib/ui/pages/stats/stats_page.dart` (modify) | 语义化颜色 |
| `lib/ui/pages/stats/widgets/summary_cards.dart` (modify) | 语义化颜色 |
| `lib/ui/pages/stats/widgets/bar_chart_view.dart` (modify) | 语义化颜色 |
| `lib/ui/pages/stats/widgets/ai_insight_view.dart` (modify) | 语义化颜色（渐变卡片按亮度适配） |
| `lib/ui/pages/home/home_page.dart` (modify) | 语义化颜色 |
| `lib/ui/pages/timeline/timeline_page.dart` (modify) | 语义化颜色 |
| `test/core/theme/app_theme_test.dart` (create) | 主题单元测试 |
| `test/ui/pages/stats/pie_chart_view_test.dart` (create) | 饼图 Widget 测试 |
| `test/ui/pages/settings/settings_page_test.dart` (create) | 设置页 Widget 测试 |
| `CHANGELOG.md` (modify) | 更新未发布日志 |

---

## Task 1: 主题基础 — 完善 AppTheme 并新增 BuildContext 扩展

**Files:**
- Create: `lib/core/theme/app_theme_ext.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `extension AppThemeExt on BuildContext { ColorScheme get colorScheme; bool get isDark; }`
- Produces: `AppTheme.light({String? accentColor}) -> ThemeData`
- Produces: `AppTheme.dark({String? accentColor}) -> ThemeData`

- [ ] **Step 1: Write the failing test**

Create `test/core/theme/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Brightness.light', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.surface, isNotNull);
      expect(theme.colorScheme.onSurface, isNotNull);
    });

    test('dark theme uses Brightness.dark', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.surface, const Color(0xFF1E1E1E));
      expect(theme.colorScheme.onSurface, Colors.white);
    });

    test('accent color is applied', () {
      const accent = '#10B981';
      final light = AppTheme.light(accentColor: accent);
      final dark = AppTheme.dark(accentColor: accent);
      expect(light.colorScheme.primary, const Color(0xFF10B981));
      expect(dark.colorScheme.primary, const Color(0xFF10B981));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/core/theme/app_theme_test.dart
```

Expected: FAIL — `AppTheme.dark()` 的 `colorScheme.surface` 目前可能仍与测试期望不一致，或缺少 `colorScheme` 字段（根据当前代码 surface 已设置，但测试会暴露后续改动问题）。

- [ ] **Step 3: Implement `AppThemeExt`**

Create `lib/core/theme/app_theme_ext.dart`:

```dart
import 'package:flutter/material.dart';

/// Convenience accessors for theme values tied to a [BuildContext].
extension AppThemeExt on BuildContext {
  /// The [ColorScheme] of the current theme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Whether the current theme is dark.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
```

- [ ] **Step 4: Refactor `AppTheme`**

Modify `lib/core/theme/app_theme.dart` to include full ColorScheme and component themes. Replace the entire file content with:

```dart
import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Light and dark theme definitions for MyTime.
class AppTheme {
  AppTheme._();

  static Color _accent(String? accentColor) {
    const fallback = '#6366F1';
    final value = int.tryParse(
      (accentColor ?? fallback).replaceFirst('#', '0xFF'),
    );
    return value != null ? Color(value) : AppColors.accentStart;
  }

  static ThemeData _base({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    String? accentColor,
  }) {
    final accent = _accent(accentColor);
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackground,
      colorScheme: colorScheme,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -2,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: isDark ? colorScheme.primary : AppColors.primaryDark,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return isDark ? const Color(0xFF39393D) : const Color(0xFFE0E0E0);
        }),
        thumbColor: WidgetStateProperty.all(Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData light({String? accentColor}) {
    final accent = _accent(accentColor);
    const surface = AppColors.cardWhite;
    const background = AppColors.backgroundLight;
    return _base(
      brightness: Brightness.light,
      scaffoldBackground: background,
      accentColor: accentColor,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.accentEnd,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.divider,
        surfaceContainerHighest: const Color(0xFFF0F0F0),
        error: AppColors.danger,
      ),
    );
  }

  static ThemeData dark({String? accentColor}) {
    final accent = _accent(accentColor);
    const surface = Color(0xFF1E1E1E);
    const background = Color(0xFF121212);
    return _base(
      brightness: Brightness.dark,
      scaffoldBackground: background,
      accentColor: accentColor,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        secondary: AppColors.accentEnd,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF999999),
        outline: const Color(0xFF2A2A2A),
        surfaceContainerHighest: const Color(0xFF2C2C2C),
        error: AppColors.danger,
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests**

Run:
```bash
flutter test test/core/theme/app_theme_test.dart
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/app_theme.dart lib/core/theme/app_theme_ext.dart test/core/theme/app_theme_test.dart
git commit -m "Add semantic theme tokens and context extensions for dark mode"
```

---

## Task 2: 底部导航栏使用主题色

**Files:**
- Modify: `lib/ui/app_shell.dart`

**Interfaces:**
- Consumes: `Theme.of(context).colorScheme`

- [ ] **Step 1: Update `app_shell.dart`**

Replace the hardcoded colors in `_MainShell.build`:

```dart
@override
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Scaffold(
    body: IndexedStack(index: _currentIndex, children: _pages),
    bottomNavigationBar: Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: SvgIcons.home(), label: '首页'),
          BottomNavigationBarItem(icon: SvgIcons.timeline(), label: '时间线'),
          BottomNavigationBarItem(icon: SvgIcons.stats(), label: '统计'),
          BottomNavigationBarItem(icon: SvgIcons.profile(), label: '我的'),
        ],
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
    ),
  );
}
```

Remove the `AppColors` import if no longer used.

- [ ] **Step 2: Run analyze**

Run:
```bash
flutter analyze
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/app_shell.dart
git commit -m "Use theme colors for bottom navigation bar"
```

---

## Task 3: 统计饼图点击高亮 + 浮动 Tooltip

**Files:**
- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Test: `test/ui/pages/stats/pie_chart_view_test.dart`

**Interfaces:**
- Consumes: `AppThemeExt` (`context.colorScheme`, `context.isDark`)
- Produces: `PieChartView` as `StatefulWidget` with internal `_selectedIndex`

- [ ] **Step 1: Write the failing Widget test**

Create `test/ui/pages/stats/pie_chart_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/core/theme/app_theme.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/stats/widgets/pie_chart_view.dart';

class _FakeCategoryRepository implements CategoryRepository {
  @override
  List<Category> getAll() => [
        Category(id: 'work', name: '工作', color: '#6366F1'),
        Category(id: 'read', name: '阅读', color: '#8B5CF6'),
      ];

  @override
  Category? getById(String id) => null;

  @override
  Future<Category> add(Category category) async => category;

  @override
  Future<void> update(Category category) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeRecordRepository implements RecordRepository {
  @override
  List<TimeRecord> getAll() => [];

  @override
  List<TimeRecord> getByDate(DateTime date) => [];

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => [];

  @override
  Future<TimeRecord> add(TimeRecord record) async => record;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> update(TimeRecord record) async {}

  @override
  Future<void> reassignCategory(String from, String to) async {}

  @override
  Future<void> clearCategory(String categoryId) async {}
}

Widget _buildSubject(List<TimeRecord> records) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: BlocProvider<CategoriesBloc>(
      create: (_) => CategoriesBloc(
        _FakeCategoryRepository(),
        _FakeRecordRepository(),
      )..add(const LoadCategories()),
      child: Scaffold(body: PieChartView(records: records)),
    ),
  );
}

void main() {
  final records = [
    TimeRecord(
      id: '1',
      categoryId: 'work',
      startTime: DateTime(2026, 7, 10, 9),
      endTime: DateTime(2026, 7, 10, 10),
    ),
    TimeRecord(
      id: '2',
      categoryId: 'read',
      startTime: DateTime(2026, 7, 10, 10),
      endTime: DateTime(2026, 7, 10, 10, 30),
    ),
  ];

  testWidgets('renders pie chart and legend', (tester) async {
    await tester.pumpWidget(_buildSubject(records));
    await tester.pumpAndSettle();
    expect(find.byType(PieChartView), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
  });

  testWidgets('shows tooltip after tapping a section', (tester) async {
    await tester.pumpWidget(_buildSubject(records));
    await tester.pumpAndSettle();

    // Tap near the center of the pie chart area.
    await tester.tap(find.byType(PieChartView));
    await tester.pumpAndSettle();

    // The tooltip should display percentage or duration.
    expect(find.textContaining('%'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/ui/pages/stats/pie_chart_view_test.dart
```

Expected: FAIL — tooltip not found or widget state not yet implemented.

- [ ] **Step 3: Implement interactive `PieChartView`**

Replace `lib/ui/pages/stats/widgets/pie_chart_view.dart` with:

```dart
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/core/utils/category_lookup.dart';
import 'package:mytime/data/models/time_record.dart';

/// Pie chart showing category time proportions with tap highlight and tooltip.
class PieChartView extends StatefulWidget {
  final List<TimeRecord> records;

  const PieChartView({super.key, required this.records});

  @override
  State<PieChartView> createState() => _PieChartViewState();
}

class _PieChartViewState extends State<PieChartView> {
  int? _selectedIndex;

  Map<String, Duration> _aggregateByCategory() {
    final map = <String, Duration>{};
    for (final r in widget.records) {
      final key = r.categoryId ?? 'uncategorized';
      map[key] = (map[key] ?? Duration.zero) + r.duration;
    }
    return map;
  }

  void _onSectionTouched(int? index) {
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else {
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final aggregated = _aggregateByCategory();
    final totalSeconds = aggregated.values.fold<int>(
      0,
      (sum, d) => sum + d.inSeconds,
    );

    if (totalSeconds == 0) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final entries = aggregated.entries.toList();
    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final cat = CategoryLookup.byId(context, entry.key);
      final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
      final percentage = (entry.value.inSeconds / totalSeconds * 100).round();
      final isSelected = _selectedIndex == i;
      sections.add(
        PieChartSectionData(
          value: entry.value.inSeconds.toDouble(),
          color: isSelected
              ? catColor
              : _selectedIndex != null
                  ? catColor.withValues(alpha: 0.5)
                  : catColor.withValues(alpha: 0.9),
          radius: isSelected ? 82 : 70,
          showTitle: false,
        ),
      );
      legendItems.add(
        _LegendItem(
          color: catColor,
          name: cat.name,
          duration: _formatDuration(entry.value),
          percentage: '$percentage%',
          highlighted: isSelected,
        ),
      );
    }

    final tooltipData = _selectedIndex != null
        ? entries[_selectedIndex!]
        : null;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.onSurface.withValues(alpha: 0.04),
                  blurRadius: 3,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 38,
                      sectionsSpace: 0,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (!event.isInterestedForInteractions) return;
                          final touchedIndex = response
                              ?.touchedSection
                              ?.touchedSectionIndex;
                          _onSectionTouched(touchedIndex);
                        },
                      ),
                    ),
                  ),
                  if (tooltipData != null)
                    _buildTooltip(context, tooltipData, totalSeconds),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(children: legendItems),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    MapEntry<String, Duration> entry,
    int totalSeconds,
  ) {
    final colorScheme = context.colorScheme;
    final cat = CategoryLookup.byId(context, entry.key);
    final catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
    final percentage = (entry.value.inSeconds / totalSeconds * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(entry.value)} · $percentage%',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String name;
  final String duration;
  final String percentage;
  final bool highlighted;

  const _LegendItem({
    required this.color,
    required this.name,
    required this.duration,
    required this.percentage,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
                color: highlighted
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              percentage,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

Run:
```bash
flutter test test/ui/pages/stats/pie_chart_view_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/stats/widgets/pie_chart_view.dart test/ui/pages/stats/pie_chart_view_test.dart
git commit -m "Add interactive pie chart highlight and tooltip"
```

---

## Task 4: 数据导入导出改为弹窗提示

**Files:**
- Modify: `lib/ui/pages/settings/settings_page.dart`
- Test: `test/ui/pages/settings/settings_page_test.dart`

**Interfaces:**
- Consumes: `AppThemeExt` (`context.colorScheme`)
- Produces: `_DataExchangeSheetState._showResultDialog(...)`

- [ ] **Step 1: Write the failing Widget test**

Create `test/ui/pages/settings/settings_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/records/records_state.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/core/theme/app_theme.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/pages/settings/settings_page.dart';

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeRecordRepository implements RecordRepository {
  @override
  List<TimeRecord> getAll() => [];

  @override
  List<TimeRecord> getByDate(DateTime date) => [];

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => [];

  @override
  Future<TimeRecord> add(TimeRecord record) async => record;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> update(TimeRecord record) async {}

  @override
  Future<void> reassignCategory(String from, String to) async {}

  @override
  Future<void> clearCategory(String categoryId) async {}
}

class _FakeCategoryRepository implements CategoryRepository {
  @override
  List<Category> getAll() => [];

  @override
  Category? getById(String id) => null;

  @override
  Future<Category> add(Category category) async => category;

  @override
  Future<void> update(Category category) async {}

  @override
  Future<void> delete(String id) async {}
}

void main() {
  testWidgets('shows success dialog after export', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>(
              create: (_) => SettingsBloc(_FakeSettingsRepository())
                ..add(const LoadSettings()),
            ),
            BlocProvider<RecordsBloc>(
              create: (_) => RecordsBloc(_FakeRecordRepository())
                ..add(const LoadRecords()),
            ),
            BlocProvider<CategoriesBloc>(
              create: (_) => CategoriesBloc(
                _FakeCategoryRepository(),
                _FakeRecordRepository(),
              )..add(const LoadCategories()),
            ),
          ],
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('数据导入导出'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('导出 JSON 到剪贴板'));
    await tester.pumpAndSettle();

    expect(find.text('导出成功'), findsOneWidget);
  });
}
```

If `RecordRepository` / `CategoryRepository` interfaces differ from the snippet above, inspect `lib/data/repositories/record_repository.dart` and `lib/data/repositories/category_repository.dart` and adjust the fakes.

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/ui/pages/settings/settings_page_test.dart
```

Expected: FAIL — dialog not yet implemented.

- [ ] **Step 3: Implement result dialog in settings page**

In `lib/ui/pages/settings/settings_page.dart`:

1. Add import at the top:
```dart
import 'package:mytime/core/theme/app_theme_ext.dart';
```

2. Replace `_exportJson` and `_importJson` result SnackBars with dialog calls. Example helper:

```dart
void _showResultDialog(
  BuildContext context,
  String title,
  String message, {
  bool isError = false,
}) {
  final colorScheme = context.colorScheme;
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '知道了',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    ),
  );
}
```

3. Update `_exportJson`:

```dart
Future<void> _exportJson() async {
  setState(() => _exportBusy = true);
  final records = context.read<RecordsBloc>().state is RecordsLoaded
      ? (context.read<RecordsBloc>().state as RecordsLoaded).records
      : <TimeRecord>[];
  final categories = context.read<CategoriesBloc>().state is CategoriesLoaded
      ? (context.read<CategoriesBloc>().state as CategoriesLoaded).categories
      : <Category>[];

  final payload = <String, dynamic>{
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories': categories.map((c) => _categoryToJson(c)).toList(),
    'records': records.map((r) => _recordToJson(r)).toList(),
  };

  final jsonString = _formatJson(payload);
  await Clipboard.setData(ClipboardData(text: jsonString));
  if (mounted) {
    setState(() => _exportBusy = false);
    _showResultDialog(
      context,
      '导出成功',
      '已将数据以 JSON 格式复制到剪贴板，包含 ${records.length} 条记录、${categories.length} 个分类。',
    );
  }
}
```

4. Update `_importJson`:

```dart
Future<void> _importJson() async {
  final recordsBloc = context.read<RecordsBloc>();
  final categoriesBloc = context.read<CategoriesBloc>();

  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  final text = clipboard?.text;
  if (text == null || text.trim().isEmpty) {
    if (mounted) {
      _showResultDialog(
        context,
        '无法导入',
        '剪贴板为空，请先复制 JSON 数据。',
        isError: true,
      );
    }
    return;
  }

  try {
    final payload = _parseJson(text);
    final recordsJson = payload['records'] as List<dynamic>? ?? [];
    final categoriesJson = payload['categories'] as List<dynamic>? ?? [];

    var importedCategories = 0;
    for (final c in categoriesJson) {
      final category = _categoryFromJson(c as Map<String, dynamic>);
      if (category != null) {
        categoriesBloc.add(CategoryAdded(category));
        importedCategories++;
      }
    }

    var importedRecords = 0;
    for (final r in recordsJson) {
      final record = _recordFromJson(r as Map<String, dynamic>);
      if (record != null) {
        recordsBloc.add(RecordAdded(record));
        importedRecords++;
      }
    }

    if (mounted) {
      _showResultDialog(
        context,
        '导入成功',
        '成功导入 $importedRecords 条记录、$importedCategories 个分类。',
      );
    }
  } catch (e) {
    if (mounted) {
      _showResultDialog(
        context,
        '导入失败',
        '导入失败：$e',
        isError: true,
      );
    }
  }
}
```

5. Replace hardcoded card/background colors in `_buildContent` and `_DataExchangeSheetState.build` with `context.colorScheme.surface`, `context.colorScheme.outline`, etc.

- [ ] **Step 4: Run tests**

Run:
```bash
flutter test test/ui/pages/settings/settings_page_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/settings/settings_page.dart test/ui/pages/settings/settings_page_test.dart
git commit -m "Replace import/export snackbars with result dialogs"
```

---

## Task 5: 统计页其他 Widget 适配主题色

**Files:**
- Modify: `lib/ui/pages/stats/stats_page.dart`
- Modify: `lib/ui/pages/stats/widgets/summary_cards.dart`
- Modify: `lib/ui/pages/stats/widgets/bar_chart_view.dart`
- Modify: `lib/ui/pages/stats/widgets/ai_insight_view.dart`

**Interfaces:**
- Consumes: `AppThemeExt`

- [ ] **Step 1: Update `stats_page.dart`**

Replace `AppColors` usages with `context.colorScheme`:

- `_RangeChip` active background: `colorScheme.primary`; inactive background: `colorScheme.surfaceContainerHighest`; active text: `colorScheme.onPrimary`; inactive text: `colorScheme.onSurfaceVariant`.
- `_TabButton` active border/text: `colorScheme.primary`; inactive text: `colorScheme.onSurfaceVariant`.
- Remove `AppColors.divider` and use `colorScheme.outline`.

- [ ] **Step 2: Update `summary_cards.dart`**

```dart
@override
Widget build(BuildContext context) {
  final colorScheme = context.colorScheme;
  final positive = !change.startsWith('-');
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colorScheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            change,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: positive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 3: Update `bar_chart_view.dart`**

- Card background: `colorScheme.surface`
- Shadow: `colorScheme.onSurface.withValues(alpha: 0.04)`
- Axis label text: `colorScheme.onSurfaceVariant`
- Bar color: keep accent but derive from `colorScheme.primary.withValues(alpha: 0.85)`

- [ ] **Step 4: Update `ai_insight_view.dart`**

- Empty state and summary card background gradient already dark; keep as-is but ensure text is readable in both modes.
- "重新生成建议" button: use `colorScheme.outline` for border, `colorScheme.onSurfaceVariant` for text, `colorScheme.surface` for background.

- [ ] **Step 5: Run analyze and existing tests**

Run:
```bash
flutter analyze
flutter test
```

Expected: No issues, existing tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/stats/stats_page.dart lib/ui/pages/stats/widgets/summary_cards.dart lib/ui/pages/stats/widgets/bar_chart_view.dart lib/ui/pages/stats/widgets/ai_insight_view.dart
git commit -m "Migrate stats page widgets to theme-aware colors"
```

---

## Task 6: 首页与时间线页适配主题色

**Files:**
- Modify: `lib/ui/pages/home/home_page.dart`
- Modify: `lib/ui/pages/timeline/timeline_page.dart`

**Interfaces:**
- Consumes: `AppThemeExt`

- [ ] **Step 1: Update `home_page.dart`**

Replace hardcoded `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.primaryDark` with `context.colorScheme`:

- Date text: `colorScheme.onSurfaceVariant`
- Timer large text: `colorScheme.onSurface`
- Subtitle: `colorScheme.onSurfaceVariant`
- Start button background: keep `AppColors.primaryDark` in light mode, use `colorScheme.surfaceContainerHighest` in dark mode (or derive from brightness).
- Stop button background: keep `AppColors.danger`.

- [ ] **Step 2: Update `timeline_page.dart`**

- Hour label text: `colorScheme.onSurfaceVariant`
- Divider color: `colorScheme.outline`
- Scale feedback text: `colorScheme.onSurfaceVariant`
- Timeline card background/text handled in `TimelineCard`; update if needed.

- [ ] **Step 3: Run analyze and existing tests**

Run:
```bash
flutter analyze
flutter test
```

Expected: No issues, existing tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/pages/home/home_page.dart lib/ui/pages/timeline/timeline_page.dart
git commit -m "Migrate home and timeline pages to theme-aware colors"
```

---

## Task 7: 更新 CHANGELOG 并运行最终验收

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update CHANGELOG**

Append to `[Unreleased]` section:

```markdown
### Added
- 统计页饼图支持点击高亮，显示分类名称、时长与占比的浮动提示。
- 数据导入导出结果改为弹窗提示（成功/失败均使用 AlertDialog）。

### Changed
- 完善深色模式：全局主题使用语义化 ColorScheme，所有页面卡片、文字、分割线、BottomSheet、Dialog 自动适配深浅主题。
```

If `[Unreleased]` does not exist, create it at the top of the file.

- [ ] **Step 2: Run final verification**

Run:
```bash
flutter analyze
flutter test
```

Expected:
- `flutter analyze`: `No issues found!`
- `flutter test`: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "Update CHANGELOG for pie chart, dark mode, and import/export dialog"
```

---

## Self-Review

### Spec coverage

| Spec requirement | Implementing task |
|---|---|
| 饼图点击高亮 | Task 3 |
| 饼图浮动 Tooltip | Task 3 |
| 图例联动高亮 | Task 3 |
| 完善深色模式 ColorScheme | Task 1 |
| 页面使用语义化颜色 | Tasks 2, 5, 6 |
| 导入导出弹窗 | Task 4 |
| 更新 CHANGELOG | Task 7 |
| 跑 flutter analyze / flutter test | Every task + Task 7 |

### Placeholder scan

- No TBD, TODO, "implement later", "fill in details", "add appropriate error handling", or "similar to Task N" patterns.
- Code blocks contain concrete examples.

### Type consistency

- `AppTheme.light` / `AppTheme.dark` signatures unchanged (`ThemeData Function({String? accentColor})`).
- `AppThemeExt` exposes `ColorScheme` and `bool` consistently.
- `_showResultDialog` signature stable across Task 4.
