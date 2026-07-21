import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mytime/blocs/records/records_bloc.dart';
import 'package:mytime/data/dtos/hive_time_record.dart';
import 'package:mytime/data/providers/hive_data_stores.dart';
import 'package:mytime/data/repositories/record_repository.dart';
import 'package:mytime/ui/pages/timeline/timeline_page.dart';

void main() {
  late RecordRepository repo;
  late Directory hiveDirectory;
  late Box<HiveTimeRecord> box;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'mytime_timeline_test_',
    );
    Hive.init(hiveDirectory.path);
    Hive.registerAdapter(HiveTimeRecordAdapter());
    box = await Hive.openBox<HiveTimeRecord>('test_timeline');
    repo = RecordRepository.withStore(HiveRecordDataStore(box));
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

  testWidgets(
    'pinch zoom restores focal time using the updated scroll extent',
    (tester) async {
      await pumpTimeline(tester);
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      final oldMaxScrollExtent = scrollable.position.maxScrollExtent;
      final initialOffset = oldMaxScrollExtent / 2;
      scrollable.position.jumpTo(initialOffset);
      final timelineListener = find.byWidgetPredicate(
        (widget) => widget is Listener && widget.onPointerMove != null,
      );
      final localFocalY = 300 - tester.getTopLeft(timelineListener).dy;
      var positionChanges = 0;
      void countPositionChange() => positionChanges++;
      scrollable.position.addListener(countPositionChange);

      final firstPointer = await tester.startGesture(
        const Offset(100, 300),
        pointer: 1,
      );
      final secondPointer = await tester.startGesture(
        const Offset(200, 300),
        pointer: 2,
      );
      await tester.pump();
      await secondPointer.moveTo(const Offset(250, 300));
      await secondPointer.moveTo(const Offset(300, 300));
      await tester.pump();
      await tester.pump();

      final expectedContentY = (initialOffset + localFocalY) * 2;
      final expectedOffset = expectedContentY - localFocalY;
      expect(scrollable.position.pixels, closeTo(expectedOffset, 0.01));
      expect(
        scrollable.position.pixels + localFocalY,
        closeTo(expectedContentY, 0.01),
      );
      expect(positionChanges, 1);

      await firstPointer.up();
      await secondPointer.up();
      await tester.pump(const Duration(milliseconds: 50));
      scrollable.position.removeListener(countPositionChange);
    },
  );

  testWidgets('shows day/week toggle tabs', (tester) async {
    await pumpTimeline(tester);

    expect(find.text('日'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
  });

  testWidgets('tapping week tab shows week view', (tester) async {
    await pumpTimeline(tester);

    await tester.tap(find.text('周'));
    await tester.pump();

    expect(find.text('一'), findsOneWidget);
  });
}
