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
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('社交'), findsOneWidget);
    expect(find.text('休息'), findsOneWidget);
    expect(find.text('创作'), findsOneWidget);
    expect(find.text('其他'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

}
