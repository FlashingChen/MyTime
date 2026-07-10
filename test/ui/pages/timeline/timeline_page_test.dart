import 'dart:io';

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
  late Directory hiveDirectory;
  late Box<TimeRecord> box;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'mytime_timeline_test_',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(TimeRecordAdapter());
    Hive.registerAdapter(CategoryAdapter());
    box = await Hive.openBox<TimeRecord>('test_timeline');
    repo = RecordRepository(box);
  });

  tearDown(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Future<void> pumpTimeline(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RecordsBloc(repo),
          child: const TimelinePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('renders 00:00 through 24:00', (tester) async {
    await pumpTimeline(tester);

    expect(find.text('00:00'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('24:00'), findsOneWidget);
  });

  testWidgets('double tap restores default scale feedback', (tester) async {
    await pumpTimeline(tester);

    await tester.tapAt(const Offset(120, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(120, 300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('100%'), findsOneWidget);
  });
}
