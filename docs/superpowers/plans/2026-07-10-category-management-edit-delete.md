# 分类管理编辑/删除扁平化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移除系统分类概念，让分类管理页中所有分类均可编辑/删除；删除分类后关联记录保留为未分类（categoryId 可空），并保证至少保留一个分类。

**Architecture:** 先修改 `Category`/`TimeRecord` 数据模型与 Hive 适配器，再逐层更新 Repository、BLoC、UI；使用 `CategoryLookup` 统一提供「未分类」兜底；所有变更伴随测试，最后更新原型与 CHANGELOG。

**Tech Stack:** Flutter、Dart、Hive、flutter_bloc、flutter_test、build_runner。

## Global Constraints

- 不新增依赖。
- 所有分类平等，不再区分系统/自定义。
- 删除分类后关联记录 `categoryId` 置为 `null`。
- 至少保留一个分类；只剩一个时禁用删除。
- 删除分类前需二次确认。
- 创建新记录必须选择分类。
- 图标仅使用 SVG 或 CustomPainter；交互命中区域至少 44×44。
- 完成后更新原型、CHANGELOG，并运行 `flutter analyze` 与 `flutter test`。

---

## File Map

| File | Responsibility |
|------|----------------|
| `lib/data/models/category.dart` | 移除 `isSystem` 字段。 |
| `lib/data/models/category.g.dart` | Hive 适配器（重新生成）。 |
| `lib/data/models/time_record.dart` | `categoryId` 改为 `String?`。 |
| `lib/data/models/time_record.g.dart` | Hive 适配器（重新生成）。 |
| `lib/core/constants/default_categories.dart` | 移除 `isSystem` 参数。 |
| `lib/data/repositories/category_repository.dart` | 移除 `isSystem` 复制逻辑。 |
| `lib/data/repositories/record_repository.dart` | 新增 `clearCategory`。 |
| `lib/blocs/categories/categories_bloc.dart` | 移除系统分类校验；删除前检查数量。 |
| `lib/core/utils/category_lookup.dart` | `byId` 接受可空 id；提供未分类兜底。 |
| `lib/ui/pages/settings/category_management_page.dart` | 所有分类显示编辑/删除；确认弹窗；最后分类禁用删除。 |
| `lib/ui/pages/home/widgets/recent_records_list.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/timeline/widgets/timeline_card.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/stats/widgets/pie_chart_view.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/stats/widgets/ai_insight_view.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/stats/stats_page.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/stats/stats_metrics.dart` | 兼容 `categoryId == null`。 |
| `lib/ui/pages/settings/settings_page.dart` | 导入导出兼容可空 categoryId。 |
| `lib/ui/pages/settings/record_management_page.dart` | 兼容可空 categoryId；编辑未分类记录需重选。 |
| `design-demos/mytime-prototype.html` | 补充分类管理页原型。 |
| `CHANGELOG.md` | 记录变更。 |

---

### Task 1: 数据模型重构

**Files:**
- Modify: `lib/data/models/category.dart`
- Modify: `lib/data/models/category.g.dart`
- Modify: `lib/data/models/time_record.dart`
- Modify: `lib/data/models/time_record.g.dart`
- Modify: `lib/core/constants/default_categories.dart`
- Modify: `test/data/models/category_test.dart`
- Modify: `test/data/models/time_record_test.dart`

**Interfaces:**
- Produces: `Category({required String id, required String name, required String color})`
- Produces: `TimeRecord({..., String? categoryId, ...})`
- Produces: `DefaultCategories.all` without `isSystem`

- [ ] **Step 1: Modify `Category` model**

Replace the entire file `lib/data/models/category.dart` with:

```dart
import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
// ignore: must_be_immutable
class Category extends HiveObject with Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.color,
  });

  Category copyWith({
    String? id,
    String? name,
    String? color,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [id, name, color];
}
```

- [ ] **Step 2: Modify `TimeRecord` model**

In `lib/data/models/time_record.dart`, change `categoryId` to nullable:

```dart
@HiveField(1)
final String? categoryId;
```

And update the constructor and `copyWith` signature:

```dart
TimeRecord({
  required this.id,
  this.categoryId,
  required this.startTime,
  required this.endTime,
  this.note,
  DateTime? createdAt,
}) : createdAt = createdAt ?? DateTime.now();

TimeRecord copyWith({
  String? id,
  String? categoryId,
  DateTime? startTime,
  DateTime? endTime,
  String? note,
  DateTime? createdAt,
}) {
  return TimeRecord(
    id: id ?? this.id,
    categoryId: categoryId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
  );
}
```

Note: `copyWith` for `categoryId` must use `categoryId: categoryId` (not `??`) so `null` can be set explicitly.

- [ ] **Step 3: Update `DefaultCategories`**

Replace `lib/core/constants/default_categories.dart` with:

```dart
import 'package:mytime/data/models/category.dart';

/// Predefined categories that ship with the app as initial data.
class DefaultCategories {
  DefaultCategories._();

  static List<Category> get all => [
    Category(id: 'work', name: '工作', color: '#6366F1'),
    Category(id: 'read', name: '阅读', color: '#8B5CF6'),
    Category(id: 'sport', name: '运动', color: '#10B981'),
    Category(id: 'study', name: '学习', color: '#F59E0B'),
    Category(id: 'social', name: '社交', color: '#EC4899'),
    Category(id: 'rest', name: '休息', color: '#6B7280'),
    Category(id: 'create', name: '创作', color: '#3B82F6'),
    Category(id: 'other', name: '其他', color: '#9CA3AF'),
  ];

  static Category byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => all.last);
  }
}
```

- [ ] **Step 4: Regenerate Hive adapters**

Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: `category.g.dart` and `time_record.g.dart` are regenerated without `isSystem` and with nullable `categoryId`.

- [ ] **Step 5: Update model tests**

Replace `test/data/models/category_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';

void main() {
  group('Category', () {
    test('creates with required fields', () {
      final category = Category(
        id: 'work',
        name: 'Work',
        color: '#6366F1',
      );
      expect(category.id, 'work');
      expect(category.name, 'Work');
      expect(category.color, '#6366F1');
    });

    test('equality works via Equatable', () {
      final c1 = Category(id: '1', name: 'Work', color: '#6366F1');
      final c2 = Category(id: '1', name: 'Work', color: '#6366F1');
      expect(c1, equals(c2));
    });

    test('copyWith creates new instance with updated fields', () {
      final category = Category(id: '1', name: 'Work', color: '#6366F1');
      final updated = category.copyWith(name: 'Updated Work');
      expect(updated.id, '1');
      expect(updated.name, 'Updated Work');
      expect(updated.color, '#6366F1');
    });
  });
}
```

In `test/data/models/time_record_test.dart`, add a nullable categoryId test:

```dart
test('allows nullable categoryId for uncategorized records', () {
  final record = TimeRecord(
    id: '1',
    categoryId: null,
    startTime: DateTime(2026, 7, 9, 8, 0),
    endTime: DateTime(2026, 7, 9, 9, 0),
  );
  expect(record.categoryId, isNull);
});

test('copyWith can set categoryId to null', () {
  final record = TimeRecord(
    id: '1',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 9, 8, 0),
    endTime: DateTime(2026, 7, 9, 9, 0),
  );
  final updated = record.copyWith(categoryId: null);
  expect(updated.categoryId, isNull);
});
```

- [ ] **Step 6: Run model tests**

Run:

```bash
flutter test test/data/models/category_test.dart test/data/models/time_record_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/data/models lib/core/constants/default_categories.dart test/data/models
flutter pub run build_runner build --delete-conflicting-outputs
git add lib/data/models/category.g.dart lib/data/models/time_record.g.dart
git commit -m "Remove isSystem and make categoryId nullable"
```

---

### Task 2: Repository 层更新

**Files:**
- Modify: `lib/data/repositories/category_repository.dart`
- Modify: `lib/data/repositories/record_repository.dart`
- Modify: `test/data/repositories/category_repository_test.dart`
- Modify: `test/data/repositories/record_repository_test.dart`

**Interfaces:**
- Consumes: `Category` without `isSystem`
- Consumes: `TimeRecord` with nullable `categoryId`
- Produces: `RecordRepository.clearCategory(String categoryId)`

- [ ] **Step 1: Update `CategoryRepository.add`**

In `lib/data/repositories/category_repository.dart`, remove `isSystem` from the copied category:

```dart
Future<Category> add(Category category) async {
  final newCategory = Category(
    id: category.id.isEmpty ? _uuid.v4() : category.id,
    name: category.name,
    color: category.color,
  );
  await _box.put(newCategory.id, newCategory);
  return newCategory;
}
```

- [ ] **Step 2: Add `RecordRepository.clearCategory`**

In `lib/data/repositories/record_repository.dart`, add after `reassignCategory`:

```dart
/// Clear the category of every saved record using the given category.
Future<void> clearCategory(String categoryId) async {
  final updates = <String, TimeRecord>{
    for (final record in _box.values.where(
      (record) => record.categoryId == categoryId,
    ))
      record.id: record.copyWith(categoryId: null),
  };
  if (updates.isNotEmpty) await _box.putAll(updates);
}
```

- [ ] **Step 3: Update `category_repository_test.dart`**

Remove the `isSystem: true` argument from the `update` test:

```dart
await repo.update(
  Category(id: 'test', name: 'Updated', color: '#FFFFFF'),
);
```

- [ ] **Step 4: Add `clearCategory` test**

Add to `test/data/repositories/record_repository_test.dart`:

```dart
test('clearCategory sets categoryId to null for matching records', () async {
  final r1 = await repo.add(TimeRecord(
    id: '',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 9, 8, 0),
    endTime: DateTime(2026, 7, 9, 9, 0),
  ));
  await repo.add(TimeRecord(
    id: '',
    categoryId: 'read',
    startTime: DateTime(2026, 7, 9, 10, 0),
    endTime: DateTime(2026, 7, 9, 11, 0),
  ));
  await repo.clearCategory('work');
  final updated = repo.getAll().firstWhere((r) => r.id == r1.id);
  expect(updated.categoryId, isNull);
  final other = repo.getAll().firstWhere((r) => r.categoryId == 'read');
  expect(other.categoryId, 'read');
});
```

- [ ] **Step 5: Run repository tests**

Run:

```bash
flutter test test/data/repositories/category_repository_test.dart test/data/repositories/record_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories test/data/repositories
git commit -m "Update repositories for category flattening"
```

---

### Task 3: BLoC 层更新

**Files:**
- Modify: `lib/blocs/categories/categories_bloc.dart`
- Modify: `test/blocs/categories/categories_bloc_test.dart`

**Interfaces:**
- Consumes: `RecordRepository.clearCategory(String categoryId)`
- Consumes: `Category` without `isSystem`
- Produces: `CategoriesError` when deleting the last category

- [ ] **Step 1: Update `CategoriesBloc._onDeleted`**

Replace `lib/blocs/categories/categories_bloc.dart` `_onDeleted` with:

```dart
Future<void> _onDeleted(
  CategoryDeleted event,
  Emitter<CategoriesState> emit,
) async {
  try {
    final category = _repository.getById(event.id);
    if (category == null) throw StateError('分类不存在');
    final all = _repository.getAll();
    if (all.length <= 1) throw StateError('至少保留一个分类');
    await _recordRepository?.clearCategory(event.id);
    await _repository.delete(event.id);
    final categories = _repository.getAll();
    emit(CategoriesLoaded(categories));
  } catch (e) {
    emit(CategoriesError(e.toString()));
  }
}
```

- [ ] **Step 2: Update BLoC tests**

Replace the "rejects deletion of a system category" test in `test/blocs/categories/categories_bloc_test.dart` with two tests:

```dart
blocTest<CategoriesBloc, CategoriesState>(
  'deletes a default category and clears its records',
  build: () => CategoriesBloc(repo),
  act: (bloc) async {
    bloc.add(const LoadCategories());
    await Future.delayed(const Duration(milliseconds: 50));
    bloc.add(const CategoryDeleted('work'));
  },
  wait: const Duration(milliseconds: 100),
  expect: () => [
    const CategoriesLoading(),
    isA<CategoriesLoaded>(),
    isA<CategoriesLoaded>(),
  ],
  verify: (bloc) {
    final state = bloc.state as CategoriesLoaded;
    expect(state.categories.any((c) => c.id == 'work'), isFalse);
  },
);

blocTest<CategoriesBloc, CategoriesState>(
  'rejects deletion of the last category',
  build: () => CategoriesBloc(repo),
  setUp: () async {
    final box = repo.getAll().first;
    for (final c in repo.getAll().where((c) => c.id != box.id).toList()) {
      await repo.delete(c.id);
    }
  },
  act: (bloc) async {
    bloc.add(const LoadCategories());
    await Future.delayed(const Duration(milliseconds: 50));
    final last = repo.getAll().single;
    bloc.add(CategoryDeleted(last.id));
  },
  wait: const Duration(milliseconds: 100),
  expect: () => [
    const CategoriesLoading(),
    isA<CategoriesLoaded>(),
    isA<CategoriesError>(),
  ],
);
```

- [ ] **Step 3: Run BLoC tests**

Run:

```bash
flutter test test/blocs/categories/categories_bloc_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/blocs/categories test/blocs/categories
git commit -m "Allow deleting all categories with last-category guard"
```

---

### Task 4: UI 与工具类更新

**Files:**
- Modify: `lib/core/utils/category_lookup.dart`
- Modify: `lib/ui/pages/settings/category_management_page.dart`
- Modify: `lib/ui/pages/home/widgets/recent_records_list.dart`
- Modify: `lib/ui/pages/timeline/widgets/timeline_card.dart`
- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Modify: `lib/ui/pages/stats/widgets/ai_insight_view.dart`
- Modify: `lib/ui/pages/stats/stats_page.dart`
- Modify: `lib/ui/pages/stats/stats_metrics.dart`
- Modify: `lib/ui/pages/settings/settings_page.dart`
- Modify: `lib/ui/pages/settings/record_management_page.dart`
- Modify: `test/ui/pages/settings/category_management_page_test.dart`
- Create: `test/ui/pages/home/widgets/recent_records_list_test.dart`
- Create: `test/ui/pages/timeline/widgets/timeline_card_test.dart`

**Interfaces:**
- Consumes: `CategoryLookup.byId(BuildContext, String?)` returns `Category`
- Produces: `CategoryManagementPage` with edit/delete for all categories
- Produces: Delete confirmation dialog with "记录将变为未分类" message

- [ ] **Step 1: Update `CategoryLookup`**

Replace `lib/core/utils/category_lookup.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';

/// Read-only category lookup that prefers the BLoC and falls back to defaults.
class CategoryLookup {
  CategoryLookup._();

  static CategoriesBloc? _tryGetBloc(BuildContext context) {
    try {
      return context.read<CategoriesBloc>();
    } catch (_) {
      return null;
    }
  }

  static List<Category> all(BuildContext context) {
    final bloc = _tryGetBloc(context);
    if (bloc != null && bloc.state is CategoriesLoaded) {
      return (bloc.state as CategoriesLoaded).categories;
    }
    return DefaultCategories.all;
  }

  static Category byId(BuildContext context, String? id) {
    if (id == null) return _uncategorized();
    final allCategories = all(context);
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => DefaultCategories.byId(id),
    );
  }

  static Category _uncategorized() => Category(
        id: '',
        name: '未分类',
        color: '#9CA3AF',
      );
}
```

- [ ] **Step 2: Update `CategoryManagementPage`**

Replace the `_CategoryListTile` construction in `lib/ui/pages/settings/category_management_page.dart` (around lines 63-71) to remove `isSystem` checks:

```dart
return _CategoryListTile(
  category: category,
  onEdit: () => _showEditDialog(context, category),
  onDelete: categories.length <= 1
      ? null
      : () => _confirmDelete(context, category),
);
```

Update `_confirmDelete` to remove replacement selection:

```dart
Future<void> _confirmDelete(BuildContext context, Category category) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除分类'),
      content: Text('删除“${category.name}”后，该分类下的记录将变为未分类。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认删除'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    context.read<CategoriesBloc>().add(CategoryDeleted(category.id));
  }
}
```

Update `_CategoryListTile` to remove the "系统" subtitle and always enable buttons when callbacks are provided:

```dart
class _CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryListTile({required this.category, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final value = int.tryParse(category.color.replaceFirst('#', '0xFF'));
    final catColor = value != null ? Color(value) : AppColors.accentStart;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: catColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: '编辑分类',
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                tooltip: '删除分类',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update all UI call sites**

In each file below, change the call from `CategoryLookup.byId(context, record.categoryId)` to allow nullable `categoryId` (the signature change in `CategoryLookup` already handles it; only ensure no local non-null assertions remain):

- `lib/ui/pages/home/widgets/recent_records_list.dart`
- `lib/ui/pages/timeline/widgets/timeline_card.dart`
- `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- `lib/ui/pages/stats/widgets/ai_insight_view.dart`
- `lib/ui/pages/stats/stats_page.dart`
- `lib/ui/pages/stats/stats_metrics.dart`
- `lib/ui/pages/settings/record_management_page.dart`

For stats widgets that use `record.categoryId` as a map key, handle null by using a constant key like `'uncategorized'`:

```dart
final key = record.categoryId ?? 'uncategorized';
map[key] = (map[key] ?? Duration.zero) + r.duration;
```

In `lib/ui/pages/settings/settings_page.dart`, the import/export JSON should handle nullable `categoryId`:

```dart
'categoryId': r.categoryId,
```

and when reading back:

```dart
categoryId: json['categoryId'] as String?,
```

- [ ] **Step 4: Update widget tests**

Replace `test/ui/pages/settings/category_management_page_test.dart` with:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/ui/pages/settings/category_management_page.dart';

void main() {
  late CategoryRepository repo;

  setUpAll(() {
    Hive.init('test_hive_category_management_page');
    if (!Hive.isAdapterRegistered(CategoryAdapter().typeId)) {
      Hive.registerAdapter(CategoryAdapter());
    }
  });

  setUp(() async {
    final box = await Hive.openBox<Category>('category_management_page_categories');
    for (final category in DefaultCategories.all) {
      await box.put(category.id, category);
    }
    repo = CategoryRepository(box);
  });

  tearDown(() async {
    await Hive.box<Category>('category_management_page_categories').clear();
    await Hive.box<Category>('category_management_page_categories').close();
  });

  tearDownAll(() async {
    await Hive.close();
    final dir = Directory('test_hive_category_management_page');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => CategoriesBloc(repo)..add(const LoadCategories()),
          child: const CategoryManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows title and default categories', (tester) async {
    await pumpPage(tester);
    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('shows edit and delete actions for default categories', (tester) async {
    await pumpPage(tester);
    expect(find.byTooltip('编辑分类'), findsWidgets);
    expect(find.byTooltip('删除分类'), findsWidgets);
  });

  testWidgets('opens delete confirmation dialog', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byTooltip('删除分类').first);
    await tester.pumpAndSettle();
    expect(find.text('删除分类'), findsOneWidget);
    expect(find.textContaining('未分类'), findsOneWidget);
  });

  // The "delete disabled when only one category remains" scenario is
  // exercised in test/blocs/categories/categories_bloc_test.dart because
  // driving CategoriesBloc + Hive real I/O through multiple deletions in a
  // widget test causes flutter_tester finalization hangs (a known limitation
  // already documented in test/integration/app_flow_test.dart).
}
```

Create `test/ui/pages/home/widgets/recent_records_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/home/widgets/recent_records_list.dart';

void main() {
  testWidgets('shows uncategorized label for null categoryId', (tester) async {
    final records = [
      TimeRecord(
        id: '1',
        categoryId: null,
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentRecordsList(records: records),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
  });
}
```

Create `test/ui/pages/timeline/widgets/timeline_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/widgets/timeline_card.dart';

void main() {
  testWidgets('shows uncategorized label for null categoryId', (tester) async {
    final record = TimeRecord(
      id: '1',
      categoryId: null,
      startTime: DateTime(2026, 7, 9, 8, 0),
      endTime: DateTime(2026, 7, 9, 9, 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineCard(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run UI tests**

Run:

```bash
flutter test test/ui/pages/settings/category_management_page_test.dart test/ui/pages/home/widgets test/ui/pages/timeline/widgets
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui lib/core/utils test/ui
git commit -m "Flatten category management UI and handle uncategorized records"
```

---

### Task 5: 原型与文档更新

**Files:**
- Modify: `design-demos/mytime-prototype.html`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: Updated prototype showing category management edit/delete flow
- Produces: Updated CHANGELOG `[Unreleased]` section

- [ ] **Step 1: Update prototype**

In `design-demos/mytime-prototype.html`, add a new `CategoryManagementScreen` component after `ProfileScreen` (before `AppPhone`). It should visually show:

- Header with back arrow and title "分类管理".
- A list of category rows, each with a colored dot, name, edit icon, and delete icon.
- A bottom "新增分类" button.
- A delete confirmation modal with title "删除分类" and text "删除后，该分类下的记录将变为未分类。" plus "取消" and "确认删除" buttons.

Wire the "分类管理" menu item in `ProfileScreen` to open this screen.

- [ ] **Step 2: Update CHANGELOG**

In `CHANGELOG.md` under `[Unreleased]`, add:

```markdown
### Added
- 分类管理页支持编辑/删除所有分类（包括默认分类）。

### Changed
- 删除分类后，关联记录保留为「未分类」状态。
- 移除「系统分类」概念，所有分类完全平等。
- 创建记录时必须选择分类；仅剩一个分类时禁止删除。
```

- [ ] **Step 3: Commit**

```bash
git add design-demos/mytime-prototype.html CHANGELOG.md
git commit -m "Update prototype and changelog for category management"
```

---

### Task 6: 最终验证

**Files:**
- All of the above (verification only)

- [ ] **Step 1: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: no issues found.

- [ ] **Step 2: Run full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Commit any final fixes**

If analysis or tests required changes, commit them:

```bash
git add -A
git commit -m "Fix analysis and test issues for category flattening"
```

---

## Self-Review

- **Spec coverage:**
  - Remove `isSystem` → Task 1.
  - `categoryId` nullable → Task 1.
  - All categories editable/deletable → Task 4.
  - Delete confirmation → Task 4.
  - Last category guard → Task 3 & 4.
  - Uncategorized display → Task 4.
  - Prototype/docs → Task 5.
  - Verification → Task 6.

- **Placeholder scan:** No TBD/TODO; all code snippets concrete.

- **Type consistency:** `CategoryLookup.byId(BuildContext, String?)` used consistently; `TimeRecord.categoryId` is `String?` across all tasks.
