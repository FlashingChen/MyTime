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
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:mytime/ui/app_shell.dart';

Widget createApp(RecordRepository repo) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => TimerBloc()),
      BlocProvider(create: (_) => RecordsBloc(repo)..add(RecordsLoaded())),
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
    late RecordRepository repo;

    setUp(() async {
      final box = await Hive.openBox<TimeRecord>('test_integration');
      repo = RecordRepository(box);
    });

    tearDown(() async {
      final box = Hive.box<TimeRecord>('test_integration');
      await box.clear();
      await box.close();
    });

    testWidgets('home shows initial timer state', (tester) async {
      await tester.pumpWidget(createApp(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('点击开始按钮开始计时'), findsOneWidget);
    });

    testWidgets('timer start and stop shows confirm bottom sheet', (tester) async {
      await tester.pumpWidget(createApp(repo));
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
    late RecordRepository repo;

    setUp(() async {
      final box = await Hive.openBox<TimeRecord>('test_integration');
      repo = RecordRepository(box);
      final now = DateTime.now();
      await repo.add(TimeRecord(
        id: '',
        categoryId: 'work',
        startTime: DateTime(now.year, now.month, now.day, 9, 0),
        endTime: DateTime(now.year, now.month, now.day, 10, 0),
      ));
    });

    tearDown(() async {
      final box = Hive.box<TimeRecord>('test_integration');
      await box.clear();
      await box.close();
    });

    testWidgets('timeline tab shows saved records', (tester) async {
      await tester.pumpWidget(createApp(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('时间线'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('日视图'), findsOneWidget);
      expect(find.text('周视图'), findsOneWidget);
      expect(find.text('工作'), findsWidgets);
    });
  });
}

class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {}
}
