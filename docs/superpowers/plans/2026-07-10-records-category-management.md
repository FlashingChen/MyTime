# 记录与分类管理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在“我的”提供全量记录的新增、编辑、删除，并让自定义分类能安全编辑和删除。

**Architecture:** Repository 对 BLoC 继续只暴露纯 Dart 接口。记录表单复用新增/编辑；删除分类先批量迁移记录再删除分类，系统分类始终受保护。

**Tech Stack:** Flutter、flutter_bloc、Hive、flutter_test。

## Global Constraints

- 不新增依赖；沿用 Hive、BLoC 与现有主题令牌。
- 系统分类不可编辑、不可删除；自定义分类可编辑、可删除。
- 记录结束时间必须晚于开始时间，且在同一自然日。
- 图标仅使用 SVG 或 CustomPainter；交互命中区域至少 44×44。
- 完成后更新原型、README、CHANGELOG，并运行 flutter analyze 与 flutter test。

---

### Task 1: 记录更新与分类迁移的数据流

**Files:**
- Modify: `lib/data/repositories/record_repository.dart`
- Modify: `lib/blocs/records/records_event.dart`
- Modify: `lib/blocs/records/records_bloc.dart`
- Modify: `lib/blocs/categories/categories_event.dart`
- Modify: `lib/blocs/categories/categories_bloc.dart`
- Modify: `lib/blocs/categories/categories_state.dart`
- Modify: `lib/main.dart`
- Modify: `test/data/repositories/record_repository_test.dart`
- Modify: `test/blocs/records/records_bloc_test.dart`
- Modify: `test/blocs/categories/categories_bloc_test.dart`

**Interfaces:**
- Produces: `RecordUpdated(TimeRecord record)`
- Produces: `RecordRepository.reassignCategory(String fromCategoryId, String toCategoryId)`
- Changes: `CategoryDeleted(id, replacementCategoryId)`
- Changes: `CategoriesBloc(CategoryRepository, RecordRepository)` and `CategoriesLoaded(categories, usageCounts)`.

- [ ] **Step 1: Write failing repository and BLoC tests**

```dart
test('reassignCategory updates every referenced record', () async {
  await repo.add(record(categoryId: 'old'));
  await repo.add(record(categoryId: 'old'));
  await repo.reassignCategory('old', 'other');
  expect(repo.getAll().every((item) => item.categoryId == 'other'), isTrue);
});

blocTest<RecordsBloc, RecordsState>(
  'updates a saved record',
  build: () => RecordsBloc(repo),
  act: (bloc) => bloc.add(RecordUpdated(existing.copyWith(note: '已修改'))),
  expect: () => [isA<RecordsLoaded>().having((state) => state.records.single.note, 'note', '已修改')],
);
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/data/repositories/record_repository_test.dart test/blocs/records/records_bloc_test.dart test/blocs/categories/categories_bloc_test.dart`  
Expected: FAIL because the event and migration method do not exist.

- [ ] **Step 3: Implement migration and update**

Implement `reassignCategory` with one `putAll` map of `copyWith(categoryId: toCategoryId)` records. Give `CategoriesBloc` the `RecordRepository`, derive `usageCounts` from `_recordRepository.getAll()` whenever it emits `CategoriesLoaded`, and update its creation in `main.dart` plus all test fixtures. Validate replacement exists and differs from the deleting ID. In CategoriesBloc migrate first and delete only after migration succeeds. Reject mutation events against a system category in the BLoC. Register `RecordUpdated`, call `_repository.update`, and emit `RecordsLoaded(_repository.getAll())`.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/data/repositories/record_repository_test.dart test/blocs/records/records_bloc_test.dart test/blocs/categories/categories_bloc_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/record_repository.dart lib/blocs/records lib/blocs/categories test/data/repositories/record_repository_test.dart test/blocs/records/records_bloc_test.dart test/blocs/categories/categories_bloc_test.dart
git commit -m "Add record update and category migration"
```

### Task 2: 自定义分类的确认和迁移 UI

**Files:**
- Modify: `lib/ui/pages/settings/category_management_page.dart`
- Modify: `lib/widgets/svg_icons.dart`
- Modify: `test/ui/pages/settings/category_management_page_test.dart`

**Interfaces:**
- Consumes: migration-aware `CategoryDeleted` and `CategoriesLoaded.usageCounts`
- Produces: edit action and a delete dialog with replacement selection when referenced.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('shows edit action for a custom category', (tester) async {
  await pumpPage(tester, categories: [customCategory]);
  expect(find.byTooltip('编辑分类'), findsOneWidget);
});

testWidgets('requires replacement before deletion of a used category', (tester) async {
  await pumpPage(tester, categories: [customCategory, otherCategory], records: [record(categoryId: customCategory.id)]);
  await tester.tap(find.byTooltip('删除分类'));
  await tester.pumpAndSettle();
  expect(find.text('替代分类'), findsOneWidget);
  expect(find.text('确认删除'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/ui/pages/settings/category_management_page_test.dart`  
Expected: FAIL because deletion dispatches immediately.

- [ ] **Step 3: Implement safe deletion dialog**

Read the category usage count from `CategoriesLoaded.usageCounts`. For unused custom categories provide cancel/delete confirmation. For referenced categories list every category except itself as a replacement and only enable deletion after one is selected. Preserve the noninteractive “系统” label for system categories. Replace touched Material icons with existing/new `SvgIcons` painters and tooltip labels.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/ui/pages/settings/category_management_page_test.dart`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/pages/settings/category_management_page.dart lib/widgets/svg_icons.dart test/ui/pages/settings/category_management_page_test.dart
git commit -m "Add safe category deletion"
```

### Task 3: 记录管理页与共享编辑器

**Files:**
- Create: `lib/ui/pages/settings/records/record_management_page.dart`
- Create: `lib/ui/pages/settings/records/widgets/record_editor_sheet.dart`
- Create: `lib/ui/pages/settings/records/widgets/record_list_item.dart`
- Modify: `lib/ui/pages/settings/settings_page.dart`
- Create: `test/ui/pages/settings/records/record_management_page_test.dart`
- Create: `test/ui/pages/settings/records/record_editor_sheet_test.dart`

**Interfaces:**
- Produces: `RecordManagementPage`
- Produces: `RecordEditorSheet({TimeRecord? initialRecord, required ValueChanged<TimeRecord> onSaved})`

- [ ] **Step 1: Write failing editor and list tests**

```dart
testWidgets('rejects an end time before start', (tester) async {
  await pumpEditor(tester, start: const TimeOfDay(hour: 10, minute: 0), end: const TimeOfDay(hour: 9, minute: 0));
  await tester.tap(find.text('保存记录'));
  await tester.pumpAndSettle();
  expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
});

testWidgets('shows newest records first and deletes after confirmation', (tester) async {
  await pumpManager(tester, records: [older, newer]);
  expect(find.text(newer.note!), findsOneWidget);
  await tester.tap(find.text(newer.note!));
  await tester.tap(find.text('删除记录'));
  await tester.tap(find.text('确认删除'));
  expect(find.text(newer.note!), findsNothing);
});
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/ui/pages/settings/records`  
Expected: FAIL because the page and editor do not exist.

- [ ] **Step 3: Implement reusable editor**

Use `showDatePicker`, `showTimePicker`, category selection and note input. Construct an edited record with existing id and createdAt, or an empty id for new records. Reject invalid time ordering and cross-day times before invoking `onSaved`.

- [ ] **Step 4: Implement list and settings entry**

Group repository-descending records by local start date. Each item shows classification color/name, time range, duration and note; tap opens the editor; deletion uses a confirmation dialog and dispatches `RecordDeleted`. Add a 44×44 SVG floating add action. Add “记录管理” before “分类管理” in `SettingsPage` with a `MaterialPageRoute`, dispatching `RecordAdded` or `RecordUpdated` after editor save.

- [ ] **Step 5: Run focused tests**

Run: `flutter test test/ui/pages/settings/records test/ui/pages/settings/settings_page_test.dart`  
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/pages/settings/records lib/ui/pages/settings/settings_page.dart lib/widgets/svg_icons.dart test/ui/pages/settings/records test/ui/pages/settings/settings_page_test.dart
git commit -m "Add record management page"
```

### Task 4: Documentation and full verification

**Files:**
- Modify: `design-demos/mytime-prototype.html`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update prototype and docs**

Add “记录管理” and add/edit/delete flows to the profile prototype. Document protected system categories and replacement migration for custom-category deletion.

- [ ] **Step 2: Update changelog**

Add Unreleased Added entries for record management and editing, and a Changed entry for safe custom-category deletion.

- [ ] **Step 3: Verify**

Run: `flutter analyze && flutter test`  
Expected: both commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add design-demos/mytime-prototype.html README.md CHANGELOG.md
git commit -m "Document record management"
```
