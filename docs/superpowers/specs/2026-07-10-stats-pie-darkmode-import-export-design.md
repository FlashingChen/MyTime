# MyTime 统计饼图点击高亮、深色模式、导入导出弹窗设计

> 文档状态：本阶段功能已实施。后续的数据完整性、DTO/Adapter 和安全存储演进不改变这里定义的用户界面；当前整体架构见 [当前架构与存储边界](../../architecture.md)。

## 1. 背景与目标

本次需要实现三个需求：

1. **统计页饼状图可点击**：点击某个扇区后高亮显示，并用浮动 Tooltip 提示该部分名称和具体数据。
2. **真正实现深色模式**：当前深色模式只改了 `scaffoldBackgroundColor`，页面中大量硬编码浅色值导致深色模式下文字、卡片、分割线、BottomSheet 等均未适配。
3. **数据导入导出成功弹窗**：导出/导入成功后改为弹窗提示，而非现有 SnackBar。

## 2. 总体方案

采用**系统级 Theme 改造**（方案 B）：

- 不修改 BLoC / Repository 接口，只改 UI 层和主题层。
- 完善 `AppTheme` 的 `ColorScheme` 与各子主题（card、dialog、bottomSheet、divider、bottomNavigationBar、appBar、switch、button）。
- 页面代码从硬编码 `AppColors.xxx` 迁移到 `Theme.of(context).colorScheme` 语义色。
- 饼图点击高亮通过 `PieChartView` 改为 StatefulWidget 实现。
- 导入导出结果通过 `showDialog` + `AlertDialog` 呈现。

## 3. 修改范围

### 3.1 新增文件

- `lib/core/theme/app_theme_ext.dart` — `BuildContext` 扩展，提供 `colorScheme` 和 `isDark` 快捷访问。

### 3.2 修改文件

- `lib/core/theme/app_theme.dart` — 完善 light/dark 两套 ThemeData。
- `lib/core/constants/app_colors.dart` — 保留设计 token，页面代码优先使用 ColorScheme。
- `lib/ui/pages/stats/widgets/pie_chart_view.dart` — 改为 StatefulWidget，增加点击高亮 + Tooltip。
- `lib/ui/pages/settings/settings_page.dart` — 导入导出结果改为 AlertDialog；移除硬编码背景色。
- `lib/ui/app_shell.dart` — BottomNavigationBar 使用主题色。
- `lib/ui/pages/stats/stats_page.dart` — 使用语义化颜色。
- `lib/ui/pages/stats/widgets/summary_cards.dart` — 使用语义化颜色。
- `lib/ui/pages/stats/widgets/bar_chart_view.dart` — 使用语义化颜色。
- `lib/ui/pages/stats/widgets/ai_insight_view.dart` — 使用语义化颜色（渐变卡片除外，按亮度选择深浅）。
- `lib/ui/pages/home/home_page.dart` — 使用语义化颜色。
- `lib/ui/pages/timeline/timeline_page.dart` — 使用语义化颜色。
- `CHANGELOG.md` — 更新 `[Unreleased]` 段。

`design-demos/mytime-prototype.html` 中暂无深色模式示例，本次不强制修改原型。

## 4. 深色模式设计

### 4.1 ColorScheme 映射

| Token | 浅色 | 深色 |
|---|---|---|
| `scaffoldBackgroundColor` | `#F8F9FA` | `#121212` |
| `colorScheme.surface` | `#FFFFFF` | `#1E1E1E` |
| `colorScheme.onSurface` | `#1D1D1F` | `#FFFFFF` |
| `colorScheme.onSurfaceVariant` | `#86868B` | `#999999` |
| `colorScheme.outline` / `divider` | `#F0F0F0` | `#2A2A2A` |
| `colorScheme.surfaceContainerHighest` | `#F0F0F0` | `#2C2C2C` |
| `primary` / `onPrimary` | accent / white | accent / white |

### 4.2 子主题配置

两套主题统一配置：

- `cardTheme`：圆角 12，背景随 `surface`。
- `dialogTheme`：圆角 24，背景随 `surface`，标题/内容颜色随 `onSurface`。
- `bottomSheetTheme`：顶部圆角 24，背景随 `surface`。
- `bottomNavigationBarTheme`：背景随 `surface`，选中/未选中颜色从 `primary` / `onSurfaceVariant` 取。
- `appBarTheme`：背景随 `scaffoldBackgroundColor`，图标/标题随 `onSurface`。
- `dividerTheme`：颜色随 `outline`。
- `switchTheme`：active track 用 accent，thumb 用 white。
- `elevatedButtonTheme` / `outlinedButtonTheme` / `textButtonTheme`：统一使用 `ColorScheme`。

### 4.3 页面代码规范

页面中统一使用：

- `context.colorScheme.surface` — 卡片/浮层背景
- `context.colorScheme.onSurface` — 主文字
- `context.colorScheme.onSurfaceVariant` — 次级文字
- `context.colorScheme.outline` — 分割线/边框
- `context.colorScheme.primary` / `.onPrimary` — 主按钮

对于 AI 洞察渐变卡片、计时器主按钮等特殊元素，仅在局部根据 `context.isDark` 做适配，并封装为独立小组件。

## 5. 统计饼图交互设计

### 5.1 状态

- `PieChartView` 改为 `StatefulWidget`。
- 新增 `_selectedIndex`：
  - 点击扇区时记录索引。
  - 再次点击同一扇区取消高亮。
  - 点击空白处取消高亮。

### 5.2 高亮效果

- 未选中扇区：`radius = 70`，`color = catColor.withOpacity(0.9)`。
- 选中扇区：`radius = 82`，`color = catColor`（不透明）。
- 其他未选中扇区：`color = catColor.withOpacity(0.5)`。
- 动画：半径变化使用 200ms 缓动。

### 5.3 浮动 Tooltip

- 触发：点击扇区时显示。
- 位置：优先跟随点击位置；若坐标计算复杂，则在饼图上方居中显示。
- 内容：分类色块 + 分类名 + 时长 + 百分比，例如：
  - 工作
  - 8h 45m
  - 35%
- 样式：圆角 12px，毛玻璃背景（`BackdropFilter` + `ImageFilter.blur`），深色模式下使用 `surface` 色带透明。

### 5.4 图例联动

- 选中某扇区时，下方对应图例项也高亮（文字加粗、颜色变为主色）。

### 5.5 无障碍

- 每个扇区加 `Semantics`，包含分类名和百分比。
- 保证点击区域不小于 44×44（通过足够大的 radius 和 `sectionsSpace`）。

## 6. 数据导入导出弹窗设计

### 6.1 改造前

- 导出成功：SnackBar “JSON 已复制到剪贴板”
- 导入成功：SnackBar “成功导入 x 条记录、y 个分类”
- 导入失败：SnackBar “导入失败：…”

### 6.2 改造后

统一使用 `AlertDialog`：

- **导出成功**
  - 标题：导出成功
  - 内容：已将数据以 JSON 格式复制到剪贴板，包含 n 条记录、m 个分类。
  - 按钮：知道了
- **导入成功**
  - 标题：导入成功
  - 内容：成功导入 n 条记录、m 个分类。
  - 按钮：知道了
- **导入失败**
  - 标题：导入失败
  - 内容：失败原因
  - 按钮：知道了
- **剪贴板为空**
  - 标题：无法导入
  - 内容：剪贴板为空，请先复制 JSON 数据。
  - 按钮：知道了

### 6.3 样式

- 圆角 24px（由 `DialogTheme.shape` 控制）。
- 背景随 `colorScheme.surface`。
- 标题/内容颜色随 `colorScheme.onSurface`。
- 按钮文字颜色随 `colorScheme.primary`。

### 6.4 实现

在 `_DataExchangeSheetState` 中新增：

```dart
void _showResultDialog(String title, String message, {bool isError = false})
```

把所有 `ScaffoldMessenger.of(context).showSnackBar(...)` 替换为 `_showResultDialog(...)`。

## 7. 测试与验收

### 7.1 单元测试

- `test/core/theme/app_theme_test.dart`
  - 验证 `AppTheme.light` / `AppTheme.dark` 的 `ColorScheme` 关键字段不为 null。
  - 验证深色 `brightness == Brightness.dark`。

### 7.2 Widget 测试

- `test/ui/pages/stats/pie_chart_view_test.dart`
  - 饼图渲染正常。
  - 点击扇区后高亮状态变化。
  - Tooltip 出现。
- `test/ui/pages/settings/settings_page_test.dart`
  - 切换深色模式开关后主题变化正确。
  - 导出成功后出现 AlertDialog，标题/内容正确。
  - 导入成功后出现 AlertDialog。
- `test/ui/pages/stats/stats_page_test.dart`
  - Tab 切换、范围切换后饼图仍可响应点击。

### 7.3 手动验收

- 浅色模式：与 `design-demos/mytime-prototype.html` 视觉一致。
- 深色模式：首页、时间线、统计、设置、导入导出弹窗、分类管理、记录管理均文字可读、卡片/背景区分明显、无硬编码浅色块。
- 饼图：点击扇区后该扇区放大，其他变暗，Tooltip 显示正确；再次点击取消。
- 导入导出：成功/失败均出现弹窗，弹窗圆角、配色正确。

### 7.4 验收命令

```bash
flutter analyze
flutter test
```
