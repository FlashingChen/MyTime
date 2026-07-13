import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/dtos/hive_category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/ui/pages/settings/category_management_page.dart';

void main() {
  late CategoryRepository repo;

  setUpAll(() {
    Hive.init('test_hive_category_management_page');
    if (!Hive.isAdapterRegistered(HiveCategoryAdapter().typeId)) {
      Hive.registerAdapter(HiveCategoryAdapter());
    }
  });

  setUp(() async {
    final box = await Hive.openBox<HiveCategory>(
      'category_management_page_categories',
    );
    for (final category in DefaultCategories.all) {
      await box.put(category.id, HiveCategory.fromDomain(category));
    }
    repo = CategoryRepository.withStore(HiveCategoryDataStore(box));
  });

  tearDown(() async {
    await Hive.box<HiveCategory>('category_management_page_categories').clear();
    await Hive.box<HiveCategory>('category_management_page_categories').close();
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

  testWidgets('shows edit and delete actions for default categories', (
    tester,
  ) async {
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

  // Note: the "disables delete when only one category remains" scenario is
  // covered by the BLoC unit test because widget tests that drive
  // CategoriesBloc + Hive real I/O hang on flutter_tester finalization.
}
