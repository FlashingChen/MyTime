# 恢复被 `git clean -fd` 删除的文件

> 文档状态：历史事故恢复记录，不是当前架构或功能的来源。当前实现请参阅 [MVP 设计规格](2026-07-09-mytime-design.md) 与 [当前架构与存储边界](../../architecture.md)。

## 背景

在合并 GitHub PR 并拉取最新 `main` 后，执行 `git clean -fd` 误删了一批未跟踪文件，导致当前暂存区中的代码（`main.dart`、`settings_page.dart`、测试文件等）引用失效，`flutter analyze` 报 45 个错误。

被删除的文件对应「分类管理、主题色、数据导入导出」功能，需要严格恢复，使项目重新可编译、可测试。

## 目标

- `flutter analyze` 0 错误、0 warning。
- `flutter test` 全部通过。
- 保留「分类管理、主题色、数据导入导出」功能。
- 不改动已暂存的调用方代码（`main.dart`、`settings_page.dart`、各测试文件等）。
- 不引入新依赖。

## 需要恢复的文件及契约

### 数据层

#### `lib/data/repositories/category_repository.dart`

封装 `Box<Category>`，对 BLoC 层暴露纯 Dart 接口。

方法：

- `List<Category> getAll()`：返回所有分类，按加入顺序或名称排序；首次调用时若 box 为空，自动把 `DefaultCategories.all` 写入 box 并返回。
- `Category? getById(String id)`：按 ID 查找。
- `Future<Category> add(Category category)`：生成 UUID（若 `id` 为空），持久化后返回。
- `Future<void> update(Category category)`：更新已有分类。
- `Future<void> delete(String id)`：删除分类。

### BLoC 层

#### `lib/blocs/categories/categories_event.dart`

```
LoadCategories
CategoryAdded(Category category)
CategoryUpdated(Category category)
CategoryDeleted(String id)
```

#### `lib/blocs/categories/categories_state.dart`

```
CategoriesInitial
CategoriesLoading
CategoriesLoaded(List<Category> categories)
CategoriesError(String message)
```

#### `lib/blocs/categories/categories_bloc.dart`

- `LoadCategories` → emit `CategoriesLoading` → `CategoriesLoaded`。
- `CategoryAdded` / `CategoryUpdated` / `CategoryDeleted` → 调用 Repository 后重新加载并 emit `CategoriesLoaded`。
- 异常时 emit `CategoriesError`。

#### `lib/blocs/categories/categories.dart`

barrel 文件，统一导出 event、state、bloc。

### 工具层

#### `lib/core/utils/category_lookup.dart`

只读降级查找工具：

- `List<Category> all(BuildContext context)`：优先从上层 `CategoriesBloc` 取已加载列表；找不到 bloc 或状态未就绪时 fallback 到 `DefaultCategories.all`。
- `Category byId(BuildContext context, String id)`：优先从 `CategoriesBloc` 按 ID 查找；找不到时 fallback 到 `DefaultCategories.byId(id)`。

该工具保证 `timeline_card.dart`、`pie_chart_view.dart`、`ai_insight_view.dart`、`confirm_bottom_sheet.dart`、`recent_records_list.dart` 在集成测试不挂载 `CategoriesBloc` 时也能正常显示分类。

### UI 层

#### `lib/ui/pages/settings/category_management_page.dart`

- 顶部返回栏 + 标题「分类管理」。
- 列表展示所有分类：色块 + 名称。
- 系统分类（`isSystem == true`）显示「系统」标签，不可删除、不可编辑。
- 自定义分类支持编辑（名称、颜色）和删除。
- 底部或顶部提供「新增分类」入口，弹出添加对话框。
- 使用 `SvgIcons.chevronLeft()` 作为返回图标（该图标已存在于 `lib/widgets/svg_icons.dart`）。

#### `lib/ui/pages/settings/widgets/color_picker.dart`

- `ColorPickerDialog.show(BuildContext context, {required String initialColor})` 返回 `Future<String?>`。
- 展示一组预设色块（覆盖默认分类色和常用色）。
- 返回选中颜色的 `#RRGGBB` 字符串。

### 测试

#### `test/blocs/categories/categories_bloc_test.dart`

覆盖：

- `LoadCategories` 事件序列：`CategoriesLoading` → `CategoriesLoaded`。
- `CategoryAdded` 后列表包含新增分类。
- `CategoryUpdated` 后分类字段更新。
- `CategoryDeleted` 后列表移除对应分类。

#### `test/data/repositories/category_repository_test.dart`

覆盖：

- 空 box 首次 `getAll()` 自动 seed 默认分类。
- `add` 生成 ID 并持久化。
- `update` 更新字段。
- `delete` 移除分类。

### 文档与 iOS 配置

#### `docs/mock-data-audit-report.md`

重建一份与当前数据模型（`TimeRecord`、`Category`、`AppSettings`）一致的 mock data audit 报告，说明默认数据、导入导出格式、字段约束等。

#### `ios/Podfile.lock`

通过 `pod install` 或按当前依赖重新生成，确保 iOS 构建一致性。

## 架构与数据流

保持现有分层：

```
Hive Box<Category>
  ↓
CategoryRepository
  ↓
CategoriesBloc (events / states)
  ↓
CategoryManagementPage / settings data exchange
```

只读路径：

```
UI 显示分类名/颜色
  ↓
CategoryLookup (BLoC → fallback DefaultCategories)
```

## 错误处理

与现有 `RecordsBloc` 一致：Repository 抛异常，BLoC catch 后 emit `CategoriesError`；UI 层当前不额外处理错误状态。

## 验收标准

1. `flutter analyze` 无错误、无 warning。
2. `flutter test` 全部通过。
3. 设置页可进入「分类管理」并正常增删改分类。
4. 设置页可修改「默认主题色」并即时生效。
5. 数据导入导出 Bottom Sheet 可正常导出 JSON 到剪贴板、从剪贴板导入。
