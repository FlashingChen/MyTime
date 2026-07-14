# Record Management Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor My → Record Management so list actions never overlap and both record endpoints support independent date and time selection, including cross-day ranges.

**Architecture:** Keep RecordsBloc and RecordsRepository unchanged. Split the current page into a BLoC-aware page shell, a presentational record card, and a stateful editor sheet; the editor returns a validated `TimeRecord` and the page dispatches the existing add/update/delete events.

**Tech Stack:** Flutter, Dart, flutter_bloc, flutter_test, existing CustomPainter icon system.

## Global Constraints

- Scope is only `我的 → 记录管理`; do not change the home timer or Category Management behavior.
- Use simplified Chinese UI copy.
- Add no dependency.
- Use the palette and spacing anchored by `design-demos/mytime-prototype.html`: `#1a1a2e`, `#6366F1`, `#8B5CF6`, `#F8F9FA`, white cards, 12 px card corners, and 24 px sheet corners.
- Touched icons must use `SvgIcons`/CustomPainter, not emoji or a newly introduced Material icon.
- Every interactive target must be at least 44×44 and expose a tooltip or semantics label.
- The end must be strictly later than the start; overnight and multi-day records are valid.
- Update the prototype, the prior design spec, and `CHANGELOG.md`.
- Run `dart format`, `flutter analyze`, and the full `flutter test` suite before completion.

---

### Task 1: Extract and Fix the Record Editor

**Files:**
- Create: `lib/ui/pages/settings/record_management/widgets/record_editor_sheet.dart`
- Create: `test/ui/pages/settings/record_management/widgets/record_editor_sheet_test.dart`

**Interfaces:**
- Produces: `Future<TimeRecord?> showRecordEditorSheet(BuildContext context, {TimeRecord? initialRecord, required List<Category> categories, DateTime? now})`
- Produces: `RecordEditorSheet({TimeRecord? initialRecord, required List<Category> categories, DateTime? now})`
- Returns: a validated `TimeRecord` through `Navigator.pop`; returns `null` when dismissed.

- [ ] **Step 1: Write the failing editor tests**

Create `test/ui/pages/settings/record_management/widgets/record_editor_sheet_test.dart` with a host that opens the real modal sheet. Use the fixed record below in all cases:

```dart
final initialRecord = TimeRecord(
  id: 'record-1',
  categoryId: 'work',
  startTime: DateTime(2026, 7, 14, 8),
  endTime: DateTime(2026, 7, 14, 9),
  note: '原备注',
  createdAt: DateTime(2026, 7, 14, 7),
);
```

Add these tests:

```dart
testWidgets('offers date and time controls for both endpoints', (tester) async {
  await openEditor(tester, initialRecord: initialRecord);

  for (final key in const [
    Key('record-editor-start-date'),
    Key('record-editor-end-date'),
  ]) {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();
  }

  for (final key in const [
    Key('record-editor-start-time'),
    Key('record-editor-end-time'),
  ]) {
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();
  }
});

testWidgets('updates endpoint date and time independently', (tester) async {
  await openEditor(tester, initialRecord: initialRecord);

  await tester.tap(find.byKey(const Key('record-editor-start-date')));
  await tester.pumpAndSettle();
  Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(
    DateTime(2026, 7, 13),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('record-editor-start-time')));
  await tester.pumpAndSettle();
  Navigator.of(tester.element(find.byType(TimePickerDialog))).pop(
    const TimeOfDay(hour: 7, minute: 30),
  );
  await tester.pumpAndSettle();

  expect(find.text('2026-07-13'), findsOneWidget);
  expect(find.text('07:30'), findsOneWidget);
  expect(find.text('2026-07-14'), findsOneWidget);
  expect(find.text('09:00'), findsOneWidget);
});

testWidgets('saves a cross-day record and preserves its identity', (tester) async {
  TimeRecord? result;
  await openEditor(
    tester,
    initialRecord: initialRecord.copyWith(
      startTime: DateTime(2026, 7, 14, 23, 30),
      endTime: DateTime(2026, 7, 15, 1),
    ),
    onResult: (value) => result = value,
  );

  await tester.tap(find.byKey(const Key('record-editor-save')));
  await tester.pumpAndSettle();

  expect(result?.id, 'record-1');
  expect(result?.createdAt, DateTime(2026, 7, 14, 7));
  expect(result?.startTime, DateTime(2026, 7, 14, 23, 30));
  expect(result?.endTime, DateTime(2026, 7, 15, 1));
});

testWidgets('shows validation and disables save for an invalid range', (tester) async {
  await openEditor(
    tester,
    initialRecord: initialRecord.copyWith(
      startTime: DateTime(2026, 7, 14, 10),
      endTime: DateTime(2026, 7, 14, 9),
    ),
  );

  expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
  final save = tester.widget<ElevatedButton>(
    find.byKey(const Key('record-editor-save')),
  );
  expect(save.onPressed, isNull);
});
```

Use this host helper so the test exercises the real modal route:

```dart
Future<void> openEditor(
  WidgetTester tester, {
  required TimeRecord initialRecord,
  ValueChanged<TimeRecord?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox(
            width: 44,
            height: 44,
            child: TextButton(
              onPressed: () async {
                final result = await showRecordEditorSheet(
                  context,
                  initialRecord: initialRecord,
                  categories: DefaultCategories.all,
                );
                onResult?.call(result);
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Run the editor tests and verify RED**

Run:

```bash
flutter test test/ui/pages/settings/record_management/widgets/record_editor_sheet_test.dart
```

Expected: FAIL because `record_editor_sheet.dart`, `showRecordEditorSheet`, and the four endpoint controls do not exist.

- [ ] **Step 3: Implement the minimal editor**

Create the public API with these exact fields and defaults:

```dart
Future<TimeRecord?> showRecordEditorSheet(
  BuildContext context, {
  TimeRecord? initialRecord,
  required List<Category> categories,
  DateTime? now,
}) {
  return showModalBottomSheet<TimeRecord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => RecordEditorSheet(
      initialRecord: initialRecord,
      categories: categories,
      now: now,
    ),
  );
}

/// Bottom-sheet form for creating or editing one local time record.
class RecordEditorSheet extends StatefulWidget {
  const RecordEditorSheet({
    super.key,
    this.initialRecord,
    required this.categories,
    this.now,
  });

  final TimeRecord? initialRecord;
  final List<Category> categories;
  final DateTime? now;

  @override
  State<RecordEditorSheet> createState() => _RecordEditorSheetState();
}
```

In `initState`, initialize a `TextEditingController`, category ID, start, and end. For a new record, use `now ?? DateTime.now()`, start one hour earlier, and choose the first category. Preserve an existing record's nullable note, ID, category, and `createdAt`.

Use these exact combination and formatting helpers so selecting a date never changes time and selecting a time never changes date:

```dart
DateTime _withDate(DateTime current, DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
  current.hour,
  current.minute,
);

DateTime _withTime(DateTime current, TimeOfDay time) => DateTime(
  current.year,
  current.month,
  current.day,
  time.hour,
  time.minute,
);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime value) =>
    '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';

String _formatTime(DateTime value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
```

Build a keyboard-safe `SingleChildScrollView` with bottom padding from `MediaQuery.viewInsetsOf(context).bottom`. Use `DropdownButtonFormField`, a note `TextField` keyed `record-editor-note`, two labeled endpoint sections, and four 48 px-high `InkWell` controls keyed exactly as the tests require. Date controls call `showDatePicker`; time controls call `showTimePicker`.

Derive `isValid = _end.isAfter(_start)`. When false, render `结束时间必须晚于开始时间` in the theme error color and set the save button's `onPressed` to `null`. When true, pop this value:

```dart
TimeRecord(
  id: widget.initialRecord?.id ?? '',
  categoryId: _categoryId,
  startTime: _start,
  endTime: _end,
  note: _noteController.text.trim().isEmpty
      ? null
      : _noteController.text.trim(),
  createdAt: widget.initialRecord?.createdAt,
)
```

Dispose the controller in `dispose`.

- [ ] **Step 4: Run the editor tests and verify GREEN**

Run:

```bash
flutter test test/ui/pages/settings/record_management/widgets/record_editor_sheet_test.dart
```

Expected: PASS with four passing widget tests and no Flutter exceptions.

- [ ] **Step 5: Commit the editor fix**

```bash
git add lib/ui/pages/settings/record_management/widgets/record_editor_sheet.dart test/ui/pages/settings/record_management/widgets/record_editor_sheet_test.dart
git commit -m "Fix record endpoint editing"
```

### Task 2: Refactor the Record List and Remove the Overlay

**Files:**
- Create: `lib/ui/pages/settings/record_management/record_management_page.dart`
- Create: `lib/ui/pages/settings/record_management/widgets/record_list_card.dart`
- Delete: `lib/ui/pages/settings/record_management_page.dart`
- Modify: `lib/ui/pages/settings/settings_page.dart`
- Modify: `lib/widgets/svg_icons.dart`
- Create: `test/ui/pages/settings/record_management/record_management_page_test.dart`

**Interfaces:**
- Consumes: `showRecordEditorSheet`, `RecordAdded`, `RecordUpdated`, and `RecordDeleted`.
- Produces: `RecordManagementPage` at its new import path.
- Produces: `RecordListCard({required TimeRecord record, required Category category, required VoidCallback onEdit, required VoidCallback onDelete})`.
- Produces: `SvgIcons.add`, `SvgIcons.edit`, and `SvgIcons.delete`.

- [ ] **Step 1: Write the failing page tests**

Create this in-memory `RecordsRepository` fake in the test file so the widget test covers the real RecordsBloc without Hive timing:

```dart
class MemoryRecordsRepository implements RecordsRepository {
  MemoryRecordsRepository(Iterable<TimeRecord> records)
    : _records = records.toList();

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<TimeRecord> _records;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  List<TimeRecord> getAll() {
    final result = List<TimeRecord>.of(_records);
    result.sort((a, b) => b.startTime.compareTo(a.startTime));
    return result;
  }

  @override
  List<TimeRecord> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return getByRange(start, end);
  }

  @override
  List<TimeRecord> getByRange(DateTime start, DateTime end) => getAll()
      .where(
        (record) =>
            record.startTime.isBefore(end) && record.endTime.isAfter(start),
      )
      .toList();

  @override
  Future<TimeRecord> add(TimeRecord record) async {
    final saved = record.id.isEmpty
        ? record.copyWith(id: 'record-${_records.length}')
        : record;
    _records.add(saved);
    _changes.add(null);
    return saved;
  }

  @override
  Future<void> update(TimeRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    _records[index] = record;
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((record) => record.id == id);
    _changes.add(null);
  }

  @override
  Future<void> reassignCategory(String fromCategoryId, String toCategoryId) async {
    for (var index = 0; index < _records.length; index++) {
      if (_records[index].categoryId == fromCategoryId) {
        _records[index] = _records[index].copyWith(categoryId: toCategoryId);
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> clearCategory(String categoryId) async {
    for (var index = 0; index < _records.length; index++) {
      if (_records[index].categoryId == categoryId) {
        _records[index] = _records[index].copyWith(categoryId: null);
      }
    }
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

List<TimeRecord> seedRecords(int count) => List.generate(
  count,
  (index) => TimeRecord(
    id: 'record-$index',
    categoryId: 'work',
    startTime: DateTime(2026, 7, 14, 8).add(Duration(hours: index)),
    endTime: DateTime(2026, 7, 14, 9).add(Duration(hours: index)),
    note: '记录 $index',
  ),
);

Future<MemoryRecordsRepository> pumpPage(
  WidgetTester tester, {
  int recordCount = 1,
  MemoryRecordsRepository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final result = repository ?? MemoryRecordsRepository(seedRecords(recordCount));
  addTearDown(result.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => RecordsBloc(result)..add(LoadRecords()),
        child: const RecordManagementPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}
```

Pump `RecordManagementPage` inside `BlocProvider(create: (_) => RecordsBloc(repository)..add(LoadRecords()))` at a logical 390×640 viewport. Seed twelve valid records with IDs `record-0` through `record-11` and category `work`.

Add these tests:

```dart
testWidgets('puts add in the header and has no floating overlay', (tester) async {
  await pumpPage(tester);

  expect(find.byKey(const Key('record-management-add')), findsOneWidget);
  expect(find.byType(FloatingActionButton), findsNothing);
});

testWidgets('keeps the last record actions visible and tappable', (tester) async {
  await pumpPage(tester, recordCount: 12);
  final delete = find.byKey(const ValueKey('record-delete-record-0'));

  await tester.scrollUntilVisible(
    delete,
    220,
    scrollable: find.byType(Scrollable),
  );
  await tester.tap(delete);
  await tester.pumpAndSettle();

  expect(find.text('删除记录'), findsOneWidget);
  expect(find.text('删除后无法恢复。'), findsOneWidget);
});

testWidgets('opens the shared editor from an edit action', (tester) async {
  await pumpPage(tester, recordCount: 1);

  await tester.tap(find.byKey(const ValueKey('record-edit-record-0')));
  await tester.pumpAndSettle();

  expect(find.text('编辑记录'), findsOneWidget);
  expect(find.byKey(const Key('record-editor-start-date')), findsOneWidget);
  expect(find.byKey(const Key('record-editor-end-time')), findsOneWidget);
});

testWidgets('dispatches an edited record without changing its identity', (tester) async {
  final repository = MemoryRecordsRepository(seedRecords(1));
  await pumpPage(tester, repository: repository);

  await tester.tap(find.byKey(const ValueKey('record-edit-record-0')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('record-editor-note')),
    '更新后的备注',
  );
  await tester.tap(find.byKey(const Key('record-editor-save')));
  await tester.pumpAndSettle();

  expect(repository.getAll().single.id, 'record-0');
  expect(repository.getAll().single.note, '更新后的备注');
});
```

- [ ] **Step 2: Run the page tests and verify RED**

Run:

```bash
flutter test test/ui/pages/settings/record_management/record_management_page_test.dart
```

Expected: FAIL because the new page/card paths and header add key do not exist and the old page still contains a `FloatingActionButton`.

- [ ] **Step 3: Add the required CustomPainter icons**

Extend `SvgIcons` with 18–24 px `add`, `edit`, and `delete` factories. Each returns a `CustomPaint` with the matching private painter:

```dart
static Widget add({double size = 24, Color? color}) => CustomPaint(
  size: Size(size, size),
  painter: _AddPainter(color: color ?? const Color(0xFF1A1A2E)),
);

static Widget edit({double size = 18, Color? color}) => CustomPaint(
  size: Size(size, size),
  painter: _EditPainter(color: color ?? const Color(0xFF86868B)),
);

static Widget delete({double size = 18, Color? color}) => CustomPaint(
  size: Size(size, size),
  painter: _DeletePainter(color: color ?? const Color(0xFFEF4444)),
);
```

All three painters use this shared stroke setup:

```dart
Paint _iconStroke(Color color) => Paint()
  ..color = color
  ..strokeWidth = 1.5
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
```

Implement the three `paint` methods with these exact primitives:

- add: centered horizontal and vertical strokes;
- edit: a diagonal pencil outline plus a short lower-left baseline;
- delete: lid, two vertical bin lines, and a rounded rectangular bin body.

Each painter stores the requested color and returns `false` from `shouldRepaint`, matching the existing icon implementation pattern.

- [ ] **Step 4: Implement the record card**

Create the documented public `RecordListCard` interface. Parse `category.color` with the existing `#RRGGBB` convention. Use a white/themed surface with 12 px corners and an `InkWell` for card editing. The content row must contain:

- a category color dot and 14 px semibold category name;
- a 12 px secondary time range;
- the optional 12 px secondary note;
- two 44×44 `IconButton`s using `SvgIcons.edit` and `SvgIcons.delete`.

Use keys `record-edit-${record.id}` and `record-delete-${record.id}`, plus tooltips `编辑记录` and `删除记录`.

Format ranges without a dependency:

```dart
String formatRecordRange(TimeRecord record) {
  final startDate = _formatDate(record.startTime);
  final endDate = _formatDate(record.endTime);
  final startTime = _formatTime(record.startTime);
  final endTime = _formatTime(record.endTime);
  if (startDate == endDate) return '$startDate $startTime–$endTime';
  return '$startDate $startTime – $endDate $endTime';
}
```

- [ ] **Step 5: Implement the refactored page**

Move `RecordManagementPage` to the new directory and update the settings import. Build a `Scaffold` without `floatingActionButton`, then a `SafeArea` containing:

- a header row with a 44×44 back action using `SvgIcons.chevronLeft`, centered `记录管理`, and a 44×44 top-right add action keyed `record-management-add` using `SvgIcons.add`;
- a loading indicator for `RecordsInitial`/`RecordsLoading`;
- the centered `暂无记录` empty state;
- an `Expanded` containing `ListView.builder` with `EdgeInsets.fromLTRB(20, 12, 20, 24)` for loaded records.

For each record, resolve its category with `CategoryLookup.byId` and build `RecordListCard`. The add and edit paths call `showRecordEditorSheet` with `CategoryLookup.all(context)` and then dispatch `RecordAdded` or `RecordUpdated` only when a non-null result returns. Keep the existing delete confirmation text and `RecordsError` SnackBar.

- [ ] **Step 6: Run the page and settings tests and verify GREEN**

Run:

```bash
flutter test test/ui/pages/settings/record_management test/ui/pages/settings/settings_page_test.dart
```

Expected: PASS. The compact-viewport test reaches the final delete action, the dialog opens, editing updates the in-memory repository, and the settings page compiles with the new import.

- [ ] **Step 7: Format and commit the UI refactor**

```bash
dart format lib/ui/pages/settings/record_management lib/ui/pages/settings/settings_page.dart lib/widgets/svg_icons.dart test/ui/pages/settings/record_management
git add lib/ui/pages/settings/record_management lib/ui/pages/settings/settings_page.dart lib/widgets/svg_icons.dart test/ui/pages/settings/record_management
git add -u lib/ui/pages/settings/record_management_page.dart
git commit -m "Refactor record management UI"
```

### Task 3: Synchronize the Prototype and Documentation

**Files:**
- Modify: `design-demos/mytime-prototype.html`
- Modify: `docs/superpowers/specs/2026-07-10-timeline-stats-record-management-design.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- No runtime interface changes.
- The prototype becomes the visual source of truth for the implemented header, cards, actions, and editor.

- [ ] **Step 1: Update the HTML prototype**

In `RecordManagementScreen`, move the add action into the existing top bar and remove any floating add treatment. Change each record row to a white 12 px card with category, formatted range, note, and visible 44×44 edit/delete controls.

Add local component state for `editingRecord` and `deleteTarget`. The editor overlay must use a 24 px top-radius sheet and contain category, note, `开始时间`, and `结束时间`. Both endpoint rows must include an `<input type="date">` and `<input type="time">`. The save action must be disabled and `结束时间必须晚于开始时间` shown whenever the end instant is not later than the start instant. The delete action must open a confirmation overlay before removing the local prototype record.

- [ ] **Step 2: Correct the prior specification**

In `docs/superpowers/specs/2026-07-10-timeline-stats-record-management-design.md`, replace both statements that limit manual record editing to the start date. State that start and end each expose independent date and time controls and that the manual editor supports cross-day records while requiring end after start.

- [ ] **Step 3: Update the changelog**

Under `[Unreleased] → Fixed`, add exactly these bullets:

```markdown
- “我的 → 记录管理”将新增入口移入顶部栏，并重构为无悬浮遮挡的记录卡片，底部记录的编辑和删除操作保持可见、可点击。
- 记录编辑器的开始与结束端点均可独立选择日期和时间，支持跨天记录，并在结束不晚于开始时阻止保存。
```

- [ ] **Step 4: Check prototype and documentation diffs**

Run:

```bash
git diff --check -- design-demos/mytime-prototype.html docs/superpowers/specs/2026-07-10-timeline-stats-record-management-design.md CHANGELOG.md
```

Expected: exit 0 with no whitespace errors.

- [ ] **Step 5: Commit synchronized design artifacts**

```bash
git add design-demos/mytime-prototype.html docs/superpowers/specs/2026-07-10-timeline-stats-record-management-design.md CHANGELOG.md
git commit -m "Update record management prototype"
```

### Task 4: Full Verification and Review

**Files:**
- Verify all files changed in Tasks 1–3.

**Interfaces:**
- No new interfaces.

- [ ] **Step 1: Verify formatting**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
```

Expected: exit 0 and `Changed 0 files`.

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: exit 0 and `No issues found!`.

- [ ] **Step 3: Run the complete test suite**

Run:

```bash
flutter test
```

Expected: exit 0 with every test passing.

- [ ] **Step 4: Inspect the final diff against the approved spec**

Run:

```bash
git status --short
git diff HEAD~3 --stat
git diff HEAD~3 -- lib/ui/pages/settings/record_management lib/ui/pages/settings/settings_page.dart lib/widgets/svg_icons.dart design-demos/mytime-prototype.html CHANGELOG.md
```

Confirm from the diff that there is no `floatingActionButton`, all four endpoint controls exist, cross-day validation uses full DateTime values, the settings route targets the new page path, and the prototype/documentation match the implementation.
