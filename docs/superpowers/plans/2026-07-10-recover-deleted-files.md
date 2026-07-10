# 恢复被删除文件实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重建被 `git clean -fd` 删除的「分类管理、主题色、数据导入导出」相关文件，使 `flutter analyze` 0 错误、`flutter test` 全过。

**Architecture:** 保持现有 Hive → Repository → BLoC → UI 分层，新增 `CategoryRepository`、`CategoriesBloc`、`CategoryLookup` 只读降级层，以及设置页所需的分类管理页和颜色选择器。

**Tech Stack:** Flutter (Dart), `flutter_bloc`, `hive_ce`, `uuid`, `bloc_test`

## Global Constraints

- 不引入新依赖。
- 不改动已暂存的调用方代码（`main.dart`、`settings_page.dart`、测试文件等）。
- 遵循 AGENTS.md 的目录、命名、BLoC、Repository 规范。
- 文案使用简体中文。
- 不使用 emoji，图标使用现有 `SvgIcons` 或 Material 图标。
- 每次任务完成后可独立运行对应测试验证。

---

## File Structure

```
lib/
├── blocs/categories/
│   ├── categories.dart           (barrel)
│   ├── categories_bloc.dart
│   ├── categories_event.dart
│   └── categories_state.dart
├── core/utils/
│   └── category_lookup.dart      (BLoC → DefaultCategories fallback)
├── data/repositories/
│   └── category_repository.dart
├── ui/pages/settings/
│   ├── category_management_page.dart
│   └── widgets/
│       └── color_picker.dart
test/
├── blocs/categories/
│   └── categories_bloc_test.dart
└── data/repositories/
    └── category_repository_test.dart
docs/
└── mock-data-audit-report.md
ios/
└── Podfile.lock                  (regenerate)
```

---

### Task 1: CategoryRepository + 单元测试

**Files:**
- Create: `lib/data/repositories/category_repository.dart`
- Create: `test/data/repositories/category_repository_test.dart`

**Interfaces:**
- Consumes: `Box<Category>` (Hive), `DefaultCategories.all`, `Uuid`
- Produces: `getAll()`, `getById(id)`, `add(category)`, `update(category)`, `delete(id)`

- [ ] **Step 1: 创建仓库实现**

Create `lib/data/repositories/category_repository.dart`:

```dart
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';

/// Repository for category persistence using Hive.
class CategoryRepository {
  final Box<Category> _box;
  final Uuid _uuid = const Uuid();
  bool _seeded = false;

  CategoryRepository(this._box);

  List<Category> getAll() {
    if (!_seeded && _box.isEmpty) {
      for (final category in DefaultCategories.all) {
        _box.put(category.id, category);
      }
      _seeded = true;
    }
    return _box.values.toList();
  }

  Category? getById(String id) {
    return _box.get(id);
  }

  Future<Category> add(Category category) async {
    final newCategory = Category(
      id: category.id.isEmpty ? _uuid.v4() : category.id,
      name: category.name,
      color: category.color,
      isSystem: category.isSystem,
    );
    await _box.put(newCategory.id, newCategory);
    return newCategory;
  }

  Future<void> update(Category category) async {
    await _box.put(category.id, category);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
```

- [ ] **Step 2: 创建仓库测试**

Create `test/data/repositories/category_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/category_repository.dart';

void main() {
  late Box<Category> box;
  late CategoryRepository repo;

  setUp(() async {
    Hive.init('test_hive_category_repo');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    box = await Hive.openBox<Category>('test_categories');
    repo = CategoryRepository(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  test('getAll seeds default categories on first load', () {
    final all = repo.getAll();
    expect(all.length, DefaultCategories.all.length);
    expect(
      all.map((c) => c.id).toSet(),
      containsAll(DefaultCategories.all.map((c) => c.id)),
    );
  });

  test('getAll returns persisted categories without reseeding', () async {
    repo.getAll();
    await repo.add(Category(id: '', name: 'Test', color: '#000000'));
    final all = repo.getAll();
    expect(all.length, DefaultCategories.all.length + 1);
  });

  test('add returns category with generated id', () async {
    final category = Category(id: '', name: 'Test', color: '#000000');
    final result = await repo.add(category);
    expect(result.id, isNotEmpty);
    expect(result.name, 'Test');
  });

  test('update changes category fields', () async {
    await repo.add(Category(id: 'test', name: 'Test', color: '#000000'));
    await repo.update(
      Category(id: 'test', name: 'Updated', color: '#FFFFFF', isSystem: true),
    );
    final updated = repo.getById('test');
    expect(updated?.name, 'Updated');
    expect(updated?.color, '#FFFFFF');
  });

  test('delete removes category', () async {
    await repo.add(Category(id: 'test', name: 'Test', color: '#000000'));
    await repo.delete('test');
    expect(repo.getById('test'), isNull);
  });
}
```

- [ ] **Step 3: 运行仓库测试**

Run:
```bash
flutter test test/data/repositories/category_repository_test.dart
```

Expected: all tests PASS.

- [ ] **Step 4: Commit（如用户要求）**

```bash
git add lib/data/repositories/category_repository.dart test/data/repositories/category_repository_test.dart
# git commit -m "feat: add CategoryRepository with default category seeding"
```

---

### Task 2: Categories BLoC + 单元测试

**Files:**
- Create: `lib/blocs/categories/categories_event.dart`
- Create: `lib/blocs/categories/categories_state.dart`
- Create: `lib/blocs/categories/categories_bloc.dart`
- Create: `lib/blocs/categories/categories.dart`
- Create: `test/blocs/categories/categories_bloc_test.dart`

**Interfaces:**
- Consumes: `CategoryRepository`
- Produces: `CategoriesBloc`, `LoadCategories`, `CategoryAdded`, `CategoryUpdated`, `CategoryDeleted`, `CategoriesLoaded`

- [ ] **Step 1: 创建事件**

Create `lib/blocs/categories/categories_event.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/category.dart';

/// Events for [CategoriesBloc].
abstract class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

/// Load all categories.
class LoadCategories extends CategoriesEvent {
  const LoadCategories();
}

/// Add a new category.
class CategoryAdded extends CategoriesEvent {
  final Category category;

  const CategoryAdded(this.category);

  @override
  List<Object?> get props => [category];
}

/// Update an existing category.
class CategoryUpdated extends CategoriesEvent {
  final Category category;

  const CategoryUpdated(this.category);

  @override
  List<Object?> get props => [category];
}

/// Delete a category by id.
class CategoryDeleted extends CategoriesEvent {
  final String id;

  const CategoryDeleted(this.id);

  @override
  List<Object?> get props => [id];
}
```

- [ ] **Step 2: 创建状态**

Create `lib/blocs/categories/categories_state.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/category.dart';

/// States for [CategoriesBloc].
abstract class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any load.
class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

/// Loading categories.
class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

/// Categories loaded successfully.
class CategoriesLoaded extends CategoriesState {
  final List<Category> categories;

  const CategoriesLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

/// Error loading categories.
class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError(this.message);

  @override
  List<Object?> get props => [message];
}
```

- [ ] **Step 3: 创建 BLoC**

Create `lib/blocs/categories/categories_bloc.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/data/repositories/category_repository.dart';

/// BLoC for managing categories.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final CategoryRepository _repository;

  CategoriesBloc(this._repository) : super(const CategoriesInitial()) {
    on<LoadCategories>(_onLoad);
    on<CategoryAdded>(_onAdded);
    on<CategoryUpdated>(_onUpdated);
    on<CategoryDeleted>(_onDeleted);
  }

  Future<void> _onLoad(LoadCategories event, Emitter<CategoriesState> emit) async {
    emit(const CategoriesLoading());
    try {
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onAdded(CategoryAdded event, Emitter<CategoriesState> emit) async {
    try {
      await _repository.add(event.category);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onUpdated(CategoryUpdated event, Emitter<CategoriesState> emit) async {
    try {
      await _repository.update(event.category);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }

  Future<void> _onDeleted(CategoryDeleted event, Emitter<CategoriesState> emit) async {
    try {
      await _repository.delete(event.id);
      final categories = _repository.getAll();
      emit(CategoriesLoaded(categories));
    } catch (e) {
      emit(CategoriesError(e.toString()));
    }
  }
}
```

- [ ] **Step 4: 创建 barrel 文件**

Create `lib/blocs/categories/categories.dart`:

```dart
export 'categories_bloc.dart';
export 'categories_event.dart';
export 'categories_state.dart';
```

- [ ] **Step 5: 创建 BLoC 测试**

Create `test/blocs/categories/categories_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/categories/categories_state.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/category_repository.dart';

void main() {
  late CategoryRepository repo;

  setUpAll(() {
    Hive.init('test_hive_categories_bloc');
    Hive.registerAdapter(CategoryAdapter());
  });

  setUp(() async {
    final box = await Hive.openBox<Category>('categories_bloc');
    repo = CategoryRepository(box);
  });

  tearDown(() async {
    await Hive.box<Category>('categories_bloc').clear();
    await Hive.box<Category>('categories_bloc').close();
  });

  group('CategoriesBloc', () {
    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded on LoadCategories',
      build: () => CategoriesBloc(repo),
      act: (bloc) => bloc.add(const LoadCategories()),
      expect: () => [
        const CategoriesLoading(),
        isA<CategoriesLoaded>(),
      ],
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded with added category',
      build: () => CategoriesBloc(repo),
      act: (bloc) async {
        bloc.add(const LoadCategories());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const CategoryAdded(Category(id: '', name: 'New', color: '#000000')));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const CategoriesLoading(),
        isA<CategoriesLoaded>(),
        isA<CategoriesLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as CategoriesLoaded;
        expect(state.categories.any((c) => c.name == 'New'), isTrue);
      },
    );

    blocTest<CategoriesBloc, CategoriesState>(
      'emits CategoriesLoaded without deleted category',
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
  });
}
```

- [ ] **Step 6: 运行 BLoC 测试**

Run:
```bash
flutter test test/blocs/categories/categories_bloc_test.dart
```

Expected: all tests PASS.

- [ ] **Step 7: Commit（如用户要求）**

```bash
git add lib/blocs/categories/ test/blocs/categories/categories_bloc_test.dart
# git commit -m "feat: add CategoriesBloc with CRUD events"
```

---

### Task 3: CategoryLookup 只读降级工具

**Files:**
- Create: `lib/core/utils/category_lookup.dart`

**Interfaces:**
- Consumes: `CategoriesBloc` (optional), `DefaultCategories`
- Produces: `CategoryLookup.all(context)`, `CategoryLookup.byId(context, id)`

- [ ] **Step 1: 创建工具类**

Create `lib/core/utils/category_lookup.dart`:

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

  static Category byId(BuildContext context, String id) {
    final allCategories = all(context);
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => DefaultCategories.byId(id),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 检查该文件**

Run:
```bash
flutter analyze lib/core/utils/category_lookup.dart
```

Expected: no issues.

- [ ] **Step 3: Commit（如用户要求）**

```bash
git add lib/core/utils/category_lookup.dart
# git commit -m "feat: add CategoryLookup fallback utility"
```

---

### Task 4: 主题色选择器 ColorPickerDialog

**Files:**
- Create: `lib/ui/pages/settings/widgets/color_picker.dart`

**Interfaces:**
- Consumes: `AppColors`
- Produces: `ColorPickerDialog.show(context, initialColor: ...)` → `Future<String?>`

- [ ] **Step 1: 创建颜色选择器**

Create `lib/ui/pages/settings/widgets/color_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Dialog for picking an accent color from a preset palette.
class ColorPickerDialog extends StatelessWidget {
  final String initialColor;

  const ColorPickerDialog({super.key, required this.initialColor});

  /// Shows the color picker and returns the selected hex color string.
  static Future<String?> show(BuildContext context, {required String initialColor}) {
    return showDialog<String>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initialColor),
    );
  }

  static const List<String> _presetColors = [
    '#6366F1',
    '#8B5CF6',
    '#10B981',
    '#F59E0B',
    '#EC4899',
    '#6B7280',
    '#3B82F6',
    '#9CA3AF',
    '#EF4444',
    '#14B8A6',
    '#F97316',
    '#84CC16',
    '#06B6D4',
    '#A855F7',
    '#64748B',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        '选择主题色',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _presetColors.map((color) {
          final isSelected = color.toUpperCase() == initialColor.toUpperCase();
          final value = int.tryParse(color.replaceFirst('#', '0xFF'));
          final catColor = value != null ? Color(value) : AppColors.accentStart;
          return GestureDetector(
            onTap: () => Navigator.pop(context, color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: BorderRadius.circular(18),
                border: isSelected
                    ? Border.all(color: AppColors.primaryDark, width: 2)
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 检查该文件**

Run:
```bash
flutter analyze lib/ui/pages/settings/widgets/color_picker.dart
```

Expected: no issues.

- [ ] **Step 3: Commit（如用户要求）**

```bash
git add lib/ui/pages/settings/widgets/color_picker.dart
# git commit -m "feat: add color picker dialog for accent color"
```

---

### Task 5: 分类管理页 CategoryManagementPage

**Files:**
- Create: `lib/ui/pages/settings/category_management_page.dart`

**Interfaces:**
- Consumes: `CategoriesBloc`, `ColorPickerDialog`
- Produces: `CategoryManagementPage` widget

- [ ] **Step 1: 创建分类管理页**

Create `lib/ui/pages/settings/category_management_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/core/constants/app_colors.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/ui/pages/settings/widgets/color_picker.dart';
import 'package:mytime/widgets/svg_icons.dart';

/// Page for managing categories.
class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: BlocBuilder<CategoriesBloc, CategoriesState>(
          builder: (context, state) {
            final categories = state is CategoriesLoaded
                ? state.categories
                : <Category>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: SvgIcons.chevronLeft(),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '分类管理',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 30),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = categories[index];
                        return _CategoryListTile(
                          category: category,
                          onEdit: () => _showEditDialog(context, category),
                          onDelete: category.isSystem
                              ? null
                              : () => context
                                  .read<CategoriesBloc>()
                                  .add(CategoryDeleted(category.id)),
                        );
                      },
                      childCount: categories.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('新增分类'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    _showCategoryDialog(context);
  }

  void _showEditDialog(BuildContext context, Category category) {
    _showCategoryDialog(context, category: category);
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final isEditing = category != null;
    final bloc = context.read<CategoriesBloc>();
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.color ?? '#6366F1';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                isEditing ? '编辑分类' : '新增分类',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: '分类名称',
                      filled: true,
                      fillColor: const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '颜色',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await ColorPickerDialog.show(
                        context,
                        initialColor: selectedColor,
                      );
                      if (picked != null) {
                        setState(() => selectedColor = picked);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(selectedColor.replaceFirst('#', '0xFF')),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    if (isEditing) {
                      bloc.add(
                        CategoryUpdated(
                          category!.copyWith(name: name, color: selectedColor),
                        ),
                      );
                    } else {
                      bloc.add(
                        CategoryAdded(
                          Category(id: '', name: name, color: selectedColor),
                        ),
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    '保存',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryListTile({
    required this.category,
    this.onEdit,
    this.onDelete,
  });

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
        subtitle: category.isSystem
            ? const Text(
                '系统',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
              )
            : null,
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
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: AppColors.danger,
                ),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 检查该文件**

Run:
```bash
flutter analyze lib/ui/pages/settings/category_management_page.dart
```

Expected: no issues.

- [ ] **Step 3: Commit（如用户要求）**

```bash
git add lib/ui/pages/settings/category_management_page.dart
# git commit -m "feat: add category management page"
```

---

### Task 6: Mock Data Audit 报告

**Files:**
- Create: `docs/mock-data-audit-report.md`

**Interfaces:**
- Produces: documentation only

- [ ] **Step 1: 创建报告**

Create `docs/mock-data-audit-report.md`:

```markdown
# Mock Data Audit Report

## 1. 数据模型概览

MyTime MVP 使用 Hive 本地存储，包含以下核心模型：

### TimeRecord

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 记录唯一标识，UUID v4 |
| categoryId | String | 关联分类 ID |
| startTime | DateTime | 开始时间 |
| endTime | DateTime | 结束时间 |
| note | String? | 可选备注 |

### Category

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 分类唯一标识 |
| name | String | 分类名称 |
| color | String | 十六进制颜色，如 `#6366F1` |
| isSystem | bool | 是否系统预设分类 |

### AppSettings

| 字段 | 类型 | 说明 |
|------|------|------|
| accentColor | String | 主题强调色 |
| themeMode | String | `light` / `dark` / `system` |
| aiApiKey | String? | AI 服务 API Key |
| aiModel | String? | AI 模型名称 |

## 2. 默认分类

应用首次启动时，`CategoryRepository` 会自动将以下系统分类写入 Hive：

- 工作 `#6366F1`
- 阅读 `#8B5CF6`
- 运动 `#10B981`
- 学习 `#F59E0B`
- 社交 `#EC4899`
- 休息 `#6B7280`
- 创作 `#3B82F6`
- 其他 `#9CA3AF`

系统分类不可删除、不可编辑，以保证数据一致性。

## 3. 数据导入导出格式

导出 JSON 包含以下字段：

```json
{
  "version": 1,
  "exportedAt": "2026-07-10T00:00:00.000",
  "categories": [...],
  "records": [...]
}
```

导入时会先写入分类，再写入记录；若字段缺失则跳过该条目。

## 4. 数据约束

- 分类颜色必须是 `#RRGGBB` 格式。
- 记录必须包含 `categoryId`、`startTime`、`endTime`。
- 系统分类 `isSystem` 为 `true`，用户自定义分类为 `false`。
```

- [ ] **Step 2: Commit（如用户要求）**

```bash
git add docs/mock-data-audit-report.md
# git commit -m "docs: add mock data audit report"
```

---

### Task 7: iOS Podfile.lock

**Files:**
- Create: `ios/Podfile.lock`

**Interfaces:**
- Produces: iOS dependency lockfile

- [ ] **Step 1: 重新生成 Podfile.lock**

Run:
```bash
cd ios && pod install
```

Expected: `Podfile.lock` recreated under `ios/`. If CocoaPods is not available, run `flutter build ios --simulator` as fallback.

- [ ] **Step 2: Commit（如用户要求）**

```bash
git add ios/Podfile.lock
# git commit -m "chore: regenerate iOS Podfile.lock"
```

---

### Task 8: 全局验证

**Files:**
- None (verification only)

- [ ] **Step 1: 运行静态分析**

Run:
```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: 运行全部测试**

Run:
```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 3: 最终 Commit（如用户要求）**

```bash
git add .
# git commit -m "feat: recover category management, accent color, and data exchange files"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** 每个被删除文件都有对应 Task。
- [x] **Placeholder scan:** 无 TBD/TODO/"implement later"。
- [x] **Type consistency:** `CategoriesBloc` / `CategoriesLoaded` / `CategoryAdded` / `CategoryUpdated` / `CategoryDeleted` 命名和用法与现有引用一致。
- [x] **No new dependencies:** 仅使用已有 `flutter_bloc`、`hive_ce`、`uuid`、`bloc_test`。
