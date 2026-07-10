import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/repositories/category_repository.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/app_shell.dart';

Widget createApp({
  required RecordRepository recordsRepo,
  required CategoryRepository categoryRepo,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => TimerBloc()),
      BlocProvider(create: (_) => RecordsBloc(recordsRepo)..add(LoadRecords())),
      // CategoriesBloc is intentionally omitted from integration tests to avoid
      // a flutter_tester finalization hang when Hive boxes are closed. Production
      // provides the bloc at the root; consumers fall back to DefaultCategories.
      BlocProvider(create: (_) => SettingsBloc(_MockSettingsRepo())..add(const LoadSettings())),
    ],
    child: const AppShell(),
  );
}

void main() {
  setUpAll(() {
    Hive.init('test_hive_integration');
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
  });

  group('empty state', () {
    late RecordRepository recordsRepo;
    late CategoryRepository categoryRepo;

    setUp(() async {
      final recordsBox = await Hive.openBox<TimeRecord>('test_integration');
      final categoriesBox = await Hive.openBox<Category>('test_integration_categories');
      recordsRepo = RecordRepository(recordsBox);
      categoryRepo = CategoryRepository(categoriesBox);
    });

    tearDown(() async {
      await Hive.box<TimeRecord>('test_integration').clear();
      await Hive.box<TimeRecord>('test_integration').close();
      await Hive.box<Category>('test_integration_categories').clear();
      await Hive.box<Category>('test_integration_categories').close();
    });

    testWidgets('home shows initial timer state', (tester) async {
      await tester.pumpWidget(createApp(recordsRepo: recordsRepo, categoryRepo: categoryRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('点击开始按钮开始计时'), findsOneWidget);
    });

    testWidgets('timer start and stop shows confirm bottom sheet', (tester) async {
      await tester.pumpWidget(createApp(recordsRepo: recordsRepo, categoryRepo: categoryRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('start_timer_button')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('正在计时'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('stop_timer_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('记录详情'), findsOneWidget);
      expect(find.text('确认保存'), findsOneWidget);
    });
  });

  group('with existing data', () {
    late RecordRepository recordsRepo;
    late CategoryRepository categoryRepo;

    setUp(() async {
      final recordsBox = await Hive.openBox<TimeRecord>('test_integration');
      final categoriesBox = await Hive.openBox<Category>('test_integration_categories');
      recordsRepo = RecordRepository(recordsBox);
      categoryRepo = CategoryRepository(categoriesBox);
      final now = DateTime.now();
      await recordsRepo.add(TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(now.year, now.month, now.day, 9, 0),
        endTime: DateTime(now.year, now.month, now.day, 10, 0),
      ));
    });

    tearDown(() async {
      await Hive.box<TimeRecord>('test_integration').clear();
      await Hive.box<TimeRecord>('test_integration').close();
      await Hive.box<Category>('test_integration_categories').clear();
      await Hive.box<Category>('test_integration_categories').close();
    });

    testWidgets('timeline tab shows saved records', (tester) async {
      await tester.pumpWidget(createApp(recordsRepo: recordsRepo, categoryRepo: categoryRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('时间线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('工作'), findsWidgets);
    });
  });
}

class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings(themeMode: 'light');

  @override
  Future<void> save(AppSettings settings) async {}
}
