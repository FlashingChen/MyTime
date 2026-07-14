# Record Management Redesign Design

**Date:** 2026-07-14
**Status:** Approved for implementation planning

## 1. Scope

This change applies only to **My → Record Management** (`我的 → 记录管理`). It does not change the home timer or Category Management page.

The redesign fixes two confirmed defects:

- The floating add button occupies the same bottom-right layer as record actions, so it can cover edit or delete controls.
- The editor exposes only a date picker for the start and only a time picker for the end. It also forces the end date to match the start date.

The result must stay local-only, add no dependency, preserve the existing RecordsBloc and repository contracts, and use simplified Chinese UI copy.

## 2. Visual and Interaction Design

The page will follow `design-demos/mytime-prototype.html` and the established settings-management pages:

- Use the standard light page background, a 56 px-style top bar, a back action, centered `记录管理` title, and a 44×44 add action at the top right.
- Remove `Scaffold.floatingActionButton`; no interactive control may overlay the record list.
- Render records as white cards with 12 px corners, 20 px horizontal page padding, 8 px vertical separation, and no heavy shadow.
- Each card shows category, a human-readable start/end range, and the optional note. Same-day ranges avoid duplicate dates; cross-day ranges show both dates explicitly.
- Each card exposes separate 44×44 edit and delete actions with tooltips and semantics. Tapping the card also edits the record.
- Keep the existing empty state, but center it inside the padded content area without an overlaid action.

Touched icons will use the existing `SvgIcons` CustomPainter system. No emoji or newly introduced Material icon is allowed.

## 3. Record Editor

New and existing records share one stateful, scrollable bottom sheet with a 24 px top radius. It remains usable with the keyboard open and on a compact phone viewport.

The field order is:

1. Title: `新增记录` or `编辑记录`.
2. Category selector.
3. Optional note input.
4. `开始时间`, containing independent date and time controls.
5. `结束时间`, containing independent date and time controls.
6. Full-width `保存记录` action.

Each date control opens `showDatePicker`; each time control opens `showTimePicker`. Picker cancellation leaves the current value unchanged. Changing one endpoint never changes the other endpoint, so overnight and multi-day records are supported.

Dates display as `YYYY-MM-DD` and times as `HH:mm`, implemented with local formatting helpers rather than a new package.

## 4. Validation and Data Flow

The editor owns temporary form state. It does not dispatch BLoC events while the user is still editing.

- The end must be strictly later than the start.
- When the range is invalid, show `结束时间必须晚于开始时间` and disable saving.
- An existing record preserves its `id` and `createdAt`; a new record keeps the current empty-ID repository flow.
- Saving returns a `TimeRecord` to the page. The page dispatches `RecordAdded` or `RecordUpdated` as appropriate.
- Delete continues to require confirmation before dispatching `RecordDeleted`.
- Existing `RecordsError` states continue to surface through a SnackBar.

No RecordsBloc or repository API change is required.

## 5. Code Organization

Refactor the current single-file implementation into a page directory:

- `record_management_page.dart`: page shell, loaded/empty/error presentation, and BLoC event dispatch.
- `widgets/record_list_card.dart`: presentational record card and accessible actions.
- `widgets/record_editor_sheet.dart`: editor state, pickers, formatting, validation, and save result.

The settings page import will be updated to the new location. The split keeps rendering, form state, and persistence coordination independently testable without changing application architecture.

## 6. Prototype and Documentation

Update the Record Management screen in `design-demos/mytime-prototype.html` to show the top-bar add action, non-overlaid record cards, explicit edit/delete actions, and the date-plus-time editor for both endpoints.

Update the earlier record-management specification to remove its obsolete same-day editor limitation, and add the two fixes to the `[Unreleased]` section of `CHANGELOG.md`.

## 7. Tests and Verification

Widget tests will cover:

- the add action is in the header and no floating action button exists;
- edit and delete actions remain visible and tappable on a compact viewport with enough records to reach the bottom;
- both endpoints expose date and time controls;
- start and end date/time selections update independently;
- a cross-day record can be saved;
- an invalid range shows the validation message and cannot be saved;
- editing preserves record identity and dispatches the updated value;
- deletion still requires confirmation.

Run focused widget tests during the red-green cycle. Before completion, run `dart format`, `flutter analyze`, and the complete `flutter test` suite.
