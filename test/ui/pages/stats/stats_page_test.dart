import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/stats/stats_page.dart';

void main() {
  late RecordRepository repo;

  setUp(() async {
    Hive.init('test_hive_stats');
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
    final box = await Hive.openBox<TimeRecord>('test_stats');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await Hive.box<TimeRecord>('test_stats').deleteFromDisk();
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
}
