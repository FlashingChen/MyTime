import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/categories/categories_bloc.dart';
import 'package:mytime/blocs/categories/categories_event.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/data/dtos/hive_category.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/pages/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    Hive.init('test_hive_settings_page');
    Hive.registerAdapter(HiveCategoryAdapter());
  });

  group('SettingsPage', () {
    late CategoryRepository categoryRepo;

    setUp(() async {
      final box = await Hive.openBox<HiveCategory>('settings_page_categories');
      categoryRepo = CategoryRepository.withStore(HiveCategoryDataStore(box));
    });

    tearDown(() async {
      await Hive.box<HiveCategory>('settings_page_categories').clear();
      await Hive.box<HiveCategory>('settings_page_categories').close();
    });

    testWidgets('shows profile and dark mode toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    SettingsBloc(settingsRepo)..add(const LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
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
      expect(find.text('WebDAV 同步'), findsOneWidget);
      expect(find.text('关于 MyTime'), findsOneWidget);
    });

    testWidgets('toggles dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    SettingsBloc(settingsRepo)..add(const LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First switch is the dark mode toggle; the second is the timer
      // reminder toggle.
      final switchFinder = find.byType(Switch).first;
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('深色模式'), findsOneWidget);
    });

    testWidgets('shows the timer reminder toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    SettingsBloc(settingsRepo)..add(const LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('计时提醒'), findsOneWidget);
      // Interval row is hidden until reminders are enabled.
      expect(find.text('提醒间隔'), findsNothing);
    });

    testWidgets('enables timer reminders and picks an interval', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    SettingsBloc(settingsRepo)..add(const LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enable reminders.
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(find.text('提醒间隔'), findsOneWidget);
      expect(find.text('30 分钟'), findsOneWidget);

      // Open the interval picker and choose 15 minutes.
      await tester.tap(find.text('提醒间隔'));
      await tester.pumpAndSettle();
      expect(find.text('15 分钟'), findsOneWidget);

      await tester.tap(find.text('15 分钟'));
      await tester.pumpAndSettle();

      expect(find.text('15 分钟'), findsOneWidget);

      // The choice was persisted.
      final reloaded = await SettingsRepository(
        secureStorage: _MemoryStore(),
      ).load();
      expect(reloaded.reminderEnabled, isTrue);
      expect(reloaded.reminderIntervalMinutes, 15);
    });

    testWidgets('opens the about dialog', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    SettingsBloc(settingsRepo)..add(const LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final aboutItem = find.text('关于 MyTime');
      await tester.ensureVisible(aboutItem);
      await tester.tap(aboutItem);
      await tester.pumpAndSettle();

      expect(find.byType(AboutDialog), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNWidgets(2));
    });

    testWidgets('opens AI configuration sheet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settingsRepo = SettingsRepository(secureStorage: _MemoryStore());

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => SettingsBloc(settingsRepo)..add(LoadSettings()),
              ),
              BlocProvider(
                create: (_) =>
                    CategoriesBloc(categoryRepo)..add(LoadCategories()),
              ),
            ],
            child: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI 模型配置'));
      await tester.pumpAndSettle();

      expect(find.text('服务地址'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);
      expect(find.text('模型名称'), findsOneWidget);
      expect(find.text('测试连接'), findsOneWidget);
      expect(find.text('保存配置'), findsOneWidget);
    });
  });
}

class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
