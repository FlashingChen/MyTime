import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/widgets/pie_chart_view.dart';

void main() {
  testWidgets('tapping a pie section shows and toggles its tooltip', (
    tester,
  ) async {
    final start = DateTime(2026, 7, 10, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PieChartView(
            records: [
              TimeRecord(
                id: 'record-1',
                categoryId: 'work',
                startTime: start,
                endTime: start.add(const Duration(hours: 2)),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsNothing);

    await tester.tapAt(const Offset(460, 130));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsOneWidget);
    expect(find.text('工作'), findsWidgets);
    expect(find.text('2h 00m'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);

    await tester.tapAt(const Offset(460, 130));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('pie_chart_tooltip')), findsNothing);
  });
}
