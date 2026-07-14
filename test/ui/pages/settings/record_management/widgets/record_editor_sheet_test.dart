import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/constants/default_categories.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/settings/record_management/widgets/record_editor_sheet.dart';

void main() {
  late TimeRecord initialRecord;

  setUp(() {
    initialRecord = TimeRecord(
      id: 'record-1',
      categoryId: 'work',
      startTime: DateTime(2026, 7, 14, 8),
      endTime: DateTime(2026, 7, 14, 9),
      note: '原备注',
      createdAt: DateTime(2026, 7, 14, 7),
    );
  });

  Future<void> openEditor(
    WidgetTester tester, {
    required TimeRecord initialRecord,
    ValueChanged<TimeRecord?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => SizedBox(
              width: 44,
              height: 44,
              child: TextButton(
                onPressed: () async {
                  final result = await showRecordEditorSheet(
                    context,
                    initialRecord: initialRecord,
                    categories: DefaultCategories.all,
                  );
                  onResult?.call(result);
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers date and time controls for both endpoints', (
    tester,
  ) async {
    await openEditor(tester, initialRecord: initialRecord);

    for (final key in const [
      Key('record-editor-start-date'),
      Key('record-editor-end-date'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();
    }

    for (final key in const [
      Key('record-editor-start-time'),
      Key('record-editor-end-time'),
    ]) {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('updates endpoint date and time independently', (tester) async {
    await openEditor(tester, initialRecord: initialRecord);

    await tester.tap(find.byKey(const Key('record-editor-start-date')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(DatePickerDialog)),
    ).pop(DateTime(2026, 7, 13));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-editor-start-time')));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(TimePickerDialog)),
    ).pop(const TimeOfDay(hour: 7, minute: 30));
    await tester.pumpAndSettle();

    expect(find.text('2026-07-13'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('2026-07-14'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('saves a cross-day record and preserves its identity', (
    tester,
  ) async {
    TimeRecord? result;
    await openEditor(
      tester,
      initialRecord: initialRecord.copyWith(
        startTime: DateTime(2026, 7, 14, 23, 30),
        endTime: DateTime(2026, 7, 15, 1),
      ),
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const Key('record-editor-save')));
    await tester.pumpAndSettle();

    expect(result?.id, 'record-1');
    expect(result?.createdAt, DateTime(2026, 7, 14, 7));
    expect(result?.startTime, DateTime(2026, 7, 14, 23, 30));
    expect(result?.endTime, DateTime(2026, 7, 15, 1));
  });

  testWidgets('shows validation and disables save for an invalid range', (
    tester,
  ) async {
    await openEditor(
      tester,
      initialRecord: initialRecord.copyWith(
        startTime: DateTime(2026, 7, 14, 10),
        endTime: DateTime(2026, 7, 14, 9),
      ),
    );

    expect(find.text('结束时间必须晚于开始时间'), findsOneWidget);
    final save = tester.widget<ElevatedButton>(
      find.byKey(const Key('record-editor-save')),
    );
    expect(save.onPressed, isNull);
  });
}
