# Statistics Category Load Design

## Goal

Ensure statistics always renders the saved name and color of a custom category after a cold app launch.

## Cause

`PieChartView` resolves category IDs while `CategoriesBloc` can still be in its initial or loading state. `CategoryLookup` then uses only `DefaultCategories`; an unknown custom ID resolves to the default `other` category. The pie view does not rebuild when `CategoriesBloc` later emits `CategoriesLoaded`.

## Chosen Design

Make `PieChartView` rebuild from `CategoriesBloc` state and resolve category IDs from that loaded state. While categories have not loaded, the view may use the existing default fallback, but it must rebuild automatically once the loaded state arrives. Records, Hive box names, category IDs, chart layout, colors, and user-facing copy remain unchanged.

## Validation

Add a widget regression test that creates a custom category and a record using it, starts the category BLoC in its loading path, and verifies that the rendered legend changes from the fallback to the saved custom name after loading. Run the focused test, `flutter analyze`, and the full `flutter test` suite.
