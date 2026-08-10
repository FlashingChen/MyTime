import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/records/records_event.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/stats/stats_page.dart';

void main() {
  late RecordRepository repo;
  late Directory hiveDirectory;
  late Box<HiveTimeRecord> box;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'mytime_stats_test_',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(HiveTimeRecordAdapter());
    box = await Hive.openBox<HiveTimeRecord>('test_stats');
    repo = RecordRepository.withStore(HiveRecordDataStore(box));
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('shows range selector and tab bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo),
          child: const StatsPage(),
        ),
      ),
    );
    expect(find.text('本日'), findsOneWidget);
    expect(find.text('本周'), findsWidgets);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('占比'), findsOneWidget);
    expect(find.text('趋势'), findsOneWidget);
    expect(find.text('AI 建议'), findsOneWidget);
  });

  testWidgets('browses previous days with the day-range date navigator', (
    tester,
  ) async {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final yesterday = dayStart.subtract(const Duration(days: 1));
    await tester.runAsync(() async {
      await repo.add(
        TimeRecord(
          id: 'today-record',
          categoryId: 'work',
          startTime: dayStart.add(const Duration(hours: 9)),
          endTime: dayStart.add(const Duration(hours: 10)),
        ),
      );
      await repo.add(
        TimeRecord(
          id: 'yesterday-record',
          categoryId: 'read',
          startTime: yesterday.add(const Duration(hours: 20)),
          endTime: yesterday.add(const Duration(hours: 22)),
        ),
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo)..add(LoadRecords()),
          child: const StatsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Week mode (default) shows no date navigator.
    expect(find.text('‹'), findsNothing);

    await tester.tap(find.text('本日'));
    await tester.pumpAndSettle();

    expect(find.text('‹'), findsOneWidget);
    expect(find.text('›'), findsOneWidget);
    expect(find.text('${dayStart.month}月${dayStart.day}日'), findsOneWidget);
    expect(find.text('今日总时长'), findsOneWidget);
    expect(find.text('1h 0m'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();

    expect(
      find.text('${yesterday.month}月${yesterday.day}日'),
      findsOneWidget,
    );
    expect(find.text('当日总时长'), findsOneWidget);
    expect(find.text('前一日总时长'), findsOneWidget);
    expect(find.text('2h 0m'), findsOneWidget);
  });
}
