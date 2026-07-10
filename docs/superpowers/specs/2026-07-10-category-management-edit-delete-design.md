# 分类管理编辑/删除扁平化设计

## 背景与目标

当前 `CategoryManagementPage` 已提供新增、编辑、删除按钮，但 `Category` 模型带有 `isSystem` 字段，系统分类在 UI 与 BLoC 层被禁止编辑/删除。用户反馈要求**不再区分系统分类与自定义分类**，所有分类应当具有相同的编辑/删除能力；删除分类时，其关联记录保留为「未分类」状态。

本设计目标：
1. 移除 `Category.isSystem` 字段及所有相关限制。
2. 将 `TimeRecord.categoryId` 改为可空，`null` 表示未分类。
3. 分类管理页中每个分类均可编辑/删除。
4. 删除分类前需二次确认，并提示记录将变为未分类。
5. 至少保留一个分类；只剩一个分类时禁用删除。
6. 创建新记录仍必须选择一个现有分类。

## 需求摘要

- 所有分类平等，默认 8 个分类作为初始数据保留但允许改名、改色、删除。
- 删除分类后，关联记录的 `categoryId` 置为 `null`。
- 删除分类需弹窗确认。
- 禁止删除最后一个分类。
- UI 中遇到 `categoryId == null` 的记录显示为「未分类」。

## 数据模型变更

### `lib/data/models/category.dart`

- 删除字段 `bool isSystem`。
- 删除 `copyWith` 中的 `isSystem` 参数。
- 更新 `props`。
- 重新生成 `category.g.dart`。

```dart
@HiveType(typeId: 1)
class Category extends HiveObject with Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String color;

  Category({required this.id, required this.name, required this.color});

  Category copyWith({String? id, String? name, String? color}) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  @override
  List<Object?> get props => [id, name, color];
}
```

### `lib/data/models/time_record.dart`

- 将 `categoryId` 从 `String` 改为 `String?`。
- `null` 表示该记录当前无分类（未分类）。

```dart
@HiveField(1)
final String? categoryId;
```

- 更新构造函数、`copyWith`、`props`。
- 重新生成 `time_record.g.dart`。

### `lib/core/constants/default_categories.dart`

- 移除 `isSystem: true` 参数。
- 默认分类仅作为首次启动时的初始数据，不再具备系统保护属性。

```dart
static List<Category> get all => [
  Category(id: 'work', name: '工作', color: '#6366F1'),
  // ... 其余 7 个
];
```

## Repository 与 BLoC 变更

### `lib/data/repositories/category_repository.dart`

- `add()` 不再复制 `isSystem`，直接按传入参数创建分类。
- `delete()` 与 `getAll()` 逻辑保持不变。
- 初始种子逻辑保持不变：Box 为空时写入 `DefaultCategories.all`。

### `lib/data/repositories/record_repository.dart`

- 新增方法：

```dart
Future<void> clearCategory(String categoryId) async {
  final updates = <String, TimeRecord>{
    for (final record in _box.values.where((r) => r.categoryId == categoryId))
      record.id: record.copyWith(categoryId: null),
  };
  if (updates.isNotEmpty) await _box.putAll(updates);
}
```

- 保留 `reassignCategory` 供未来记录迁移复用。

### `lib/blocs/categories/categories_bloc.dart`

- 移除 `_onDeleted` 中对 `category.isSystem` 的检查。
- 删除前校验：若当前分类总数为 1，则抛出异常（UI 层应提前禁用删除按钮，此为兜底）。
- 删除流程：先调用 `_recordRepository?.clearCategory(event.id)`，再调用 `_repository.delete(event.id)`，最后重新加载并发射 `CategoriesLoaded`。

```dart
Future<void> _onDeleted(CategoryDeleted event, Emitter<CategoriesState> emit) async {
  try {
    final category = _repository.getById(event.id);
    if (category == null) throw StateError('分类不存在');
    final all = _repository.getAll();
    if (all.length <= 1) throw StateError('至少保留一个分类');
    await _recordRepository?.clearCategory(event.id);
    await _repository.delete(event.id);
    emit(CategoriesLoaded(_repository.getAll()));
  } catch (e) {
    emit(CategoriesError(e.toString()));
  }
}
```

- `CategoryUpdated` 保持不变，任何分类均可更新。

## UI 变更

### `lib/ui/pages/settings/category_management_page.dart`

- `_CategoryListTile`：
  - 移除 `category.isSystem` 判断，编辑/删除按钮始终显示。
  - 移除「系统」标签。
  - 删除按钮在只剩一个分类时 `onPressed: null`。
- `_confirmDelete`：
  - 不再提供替代分类选择。
  - 确认框文案：「删除后，该分类下的记录将变为未分类。」
  - 确认后直接派发 `CategoryDeleted(category.id)`。
- 页面底部新增提示文案：当分类列表只剩一个时显示「至少保留一个分类」。
- 编辑弹窗标题统一为「编辑分类」，任何分类均可修改名称与颜色。

### `lib/core/utils/category_lookup.dart`

- `byId(context, categoryId)` 在 `categoryId == null` 或找不到分类时，返回虚拟「未分类」分类：
  - `name: '未分类'`
  - `color: '#9CA3AF'`

```dart
Category fallback() => Category(id: '', name: '未分类', color: '#9CA3AF');
```

### 首页、时间线、统计页

- 将 `record.categoryId` 传入 `CategoryLookup.byId` 时允许为空。
- 统计图表中「未分类」单独作为一项，使用灰色。

### 记录编辑器

- `RecordEditorSheet` 中分类下拉默认选中第一个现有分类，且不允许为空。
- 编辑一条「未分类」历史记录时，必须重新选择一个现有分类才能保存。

## 测试计划

### 数据与 Repository 测试

- `test/data/models/category_test.dart`：移除 `isSystem` 断言，更新 equality 测试。
- `test/data/repositories/category_repository_test.dart`：移除 `isSystem` 断言；验证新增分类不带 `isSystem`。
- `test/data/repositories/record_repository_test.dart`：新增 `clearCategory` 测试，验证删除分类后关联记录 `categoryId` 为 `null`。

### BLoC 测试

- `test/blocs/categories/categories_bloc_test.dart`：
  - 移除「系统分类不可删除」测试。
  - 新增「删除分类后关联记录变为未分类」测试。
  - 新增「只剩一个分类时删除失败」测试。
  - 更新「编辑分类」测试，覆盖默认分类。

### Widget 测试

- `test/ui/pages/settings/category_management_page_test.dart`：
  - 默认分类显示编辑/删除按钮。
  - 点击编辑可修改名称颜色并保存。
  - 点击删除弹出确认框。
  - 只剩一个分类时删除按钮禁用。
- `test/ui/pages/home/widgets/recent_records_list_test.dart` / `timeline_card_test.dart`：
  - `categoryId == null` 时显示「未分类」。

## 原型与文档更新

- `design-demos/mytime-prototype.html`：补充分类管理页高保真原型，展示每个分类右侧编辑/删除图标，以及删除确认弹窗。
- `CHANGELOG.md`：在 `[Unreleased]` 新增条目：
  - 分类管理支持编辑/删除所有分类。
  - 删除分类后关联记录保留为未分类。
  - 移除系统分类概念。
- `AGENTS.md`：本次不涉及规范调整，保持不动。

## 验证标准

- `flutter analyze` 无错误/警告。
- `flutter test` 全部通过。
- 手动验证：
  - 可编辑默认分类名称与颜色。
  - 可删除默认分类，关联记录显示为「未分类」。
  - 只剩一个分类时无法删除。
  - 新建记录必须选择分类。
