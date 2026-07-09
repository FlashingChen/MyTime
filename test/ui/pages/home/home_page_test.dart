import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/blocs/timer/timer_bloc.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/home/home_page.dart';

void main() {
  late RecordRepository repo;

  setUp(() async {
    Hive.init('test_hive_home');
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
    final box = await Hive.openBox<TimeRecord>('test_home');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await Hive.box<TimeRecord>('test_home').deleteFromDisk();
  });

  testWidgets('shows 00:00 and start button in idle state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => TimerBloc()),
            BlocProvider(create: (_) => RecordsBloc(repo)),
          ],
          child: const HomePage(),
        ),
      ),
    );
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('点击开始按钮开始计时'), findsOneWidget);
  });
}
