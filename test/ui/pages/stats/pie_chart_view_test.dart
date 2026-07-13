import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/ui/pages/stats/widgets/pie_chart_view.dart';

void main() {
  testWidgets('renders default categories without a CategoriesBloc provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PieChartView(
            categoryDurations: const {'work': Duration(hours: 2)},
          ),
        ),
      ),
    );

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('2h 00m'), findsOneWidget);
  });

  testWidgets('tapping a pie section shows and toggles its tooltip', (
    tester,
  ) async {
    final categoriesBloc = CategoriesBloc(_TestCategoryRepository([]));
    addTearDown(categoriesBloc.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: categoriesBloc,
          child: Scaffold(
            body: PieChartView(
              categoryDurations: const {'work': Duration(hours: 2)},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsNothing);

    await tester.tapAt(const Offset(460, 130));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsOneWidget);
    expect(find.text('工作'), findsWidgets);
    expect(find.text('2h 00m'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);

    await tester.tapAt(const Offset(460, 130));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsNothing);
  });

  testWidgets('shows a custom category after categories finish loading', (
    tester,
  ) async {
    final categoriesBloc = CategoriesBloc(
      _TestCategoryRepository([
        Category(id: 'custom-id', name: '自定义分类', color: '#123456'),
      ]),
    );
    addTearDown(categoriesBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: categoriesBloc,
          child: Scaffold(
            body: PieChartView(
              categoryDurations: const {'custom-id': Duration(hours: 2)},
            ),
          ),
        ),
      ),
    );

    expect(find.text('未分类'), findsOneWidget);

    categoriesBloc.add(const LoadCategories());
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('自定义分类'), findsOneWidget);
  });
}

class _TestCategoryRepository extends CategoryRepository {
  final List<Category> categories;

  _TestCategoryRepository(this.categories)
    : super.withStore(_TestCategoryStore());

  @override
  List<Category> getAll() => categories;
}

class _TestCategoryStore implements CategoryDataStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
