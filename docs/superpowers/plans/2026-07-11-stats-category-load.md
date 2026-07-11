# Statistics Category Load Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render custom category names in statistics after category data finishes loading on a cold launch.

**Architecture:** Keep records keyed by `categoryId`. Let the statistics pie view rebuild when `CategoriesBloc` emits a new state, then resolve every record category through the loaded BLoC state. This changes presentation refresh only; it does not migrate Hive data.

**Tech Stack:** Flutter, flutter_bloc, Hive CE, flutter_test.

## Global Constraints

- Do not add dependencies or modify Hive schemas, boxes, stored records, or category IDs.
- Preserve the existing statistics layout, Chinese copy, default category colors, and fallback behavior for genuinely unknown IDs.
- Add a widget test that fails before the refresh behavior exists.
- Update `CHANGELOG.md` under `[Unreleased]`.

---

### Task 1: Refresh custom category labels in the statistics pie view

**Files:**
- Modify: `lib/ui/pages/stats/widgets/pie_chart_view.dart`
- Modify: `test/ui/pages/stats/pie_chart_view_test.dart`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: `CategoriesBloc` and `CategoriesState` from `lib/blocs/categories/`.
- Produces: `PieChartView` that updates its rendered category label when `CategoriesLoaded` is emitted.

- [ ] **Step 1: Write the failing widget test**

Create a custom category with ID `custom-id` and name `自定义分类`, provide a record using `custom-id`, and start `CategoriesBloc` with `LoadCategories`. Pump once so the initial fallback renders, then pump again after the load event. Assert that the legend contains `自定义分类`; the current implementation keeps `其他`, so this assertion fails.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `flutter test test/ui/pages/stats/pie_chart_view_test.dart`

Expected: FAIL because `PieChartView` does not listen to `CategoriesBloc` after the first build.

- [ ] **Step 3: Implement the minimal refresh behavior**

Wrap the pie view's category-resolution build path in `BlocBuilder<CategoriesBloc, CategoriesState>`. Continue using `CategoryLookup.byId(context, entry.key)` so the existing fallback behavior is preserved; rebuilding after `CategoriesLoaded` makes the lookup see persisted custom categories.

- [ ] **Step 4: Verify the focused test passes**

Run: `flutter test test/ui/pages/stats/pie_chart_view_test.dart`

Expected: PASS, including the existing tooltip interaction test and the custom-category cold-start regression test.

- [ ] **Step 5: Update the changelog**

Add `- Fix statistics category labels after a cold launch.` to the `[Unreleased]` section in `CHANGELOG.md`.

- [ ] **Step 6: Run full verification**

Run: `flutter analyze` and `flutter test`.

Expected: both commands exit successfully with no new analyzer issues or test failures.
