import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/timeline/timeline_page.dart';

void main() {
  late RecordRepository repo;

  setUp(() async {
    Hive.init('test_hive_timeline');
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
    final box = await Hive.openBox<TimeRecord>('test_timeline');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await Hive.box<TimeRecord>('test_timeline').deleteFromDisk();
  });

  testWidgets('shows date and view toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo),
          child: const TimelinePage(),
        ),
      ),
    );
    expect(find.text('日视图'), findsOneWidget);
    expect(find.text('周视图'), findsOneWidget);
  });
}
