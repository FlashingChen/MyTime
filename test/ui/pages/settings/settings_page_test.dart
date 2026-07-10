import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/pages/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    Hive.init('test_hive_settings_page');
    Hive.registerAdapter(CategoryAdapter());
  });

  group('SettingsPage', () {
    late CategoryRepository categoryRepo;

    setUp(() async {
      final box = await Hive.openBox<Category>('settings_page_categories');
      categoryRepo = CategoryRepository(box);
    });

    tearDown(() async {
      await Hive.box<Category>('settings_page_categories').clear();
      await Hive.box<Category>('settings_page_categories').close();
    });

    testWidgets('shows profile and dark mode toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SettingsBloc(settingsRepo)..add(const LoadSettings())),
              BlocProvider(create: (_) => CategoriesBloc(categoryRepo)..add(LoadCategories())),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MyTime'), findsOneWidget);
      expect(find.text('本地账户'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
      expect(find.text('分类管理'), findsOneWidget);
      expect(find.text('默认主题色'), findsOneWidget);
      expect(find.text('AI 模型配置'), findsOneWidget);
      expect(find.text('数据导入导出'), findsOneWidget);
      expect(find.text('关于 MyTime'), findsOneWidget);
    });

    testWidgets('toggles dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => SettingsBloc(settingsRepo)..add(const LoadSettings())),
              BlocProvider(create: (_) => CategoriesBloc(categoryRepo)..add(LoadCategories())),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('深色模式'), findsOneWidget);
    });
  });
}