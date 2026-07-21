import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/widgets/week_view.dart';

void main() {
  testWidgets('renders 7-day stacked bars for the week', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekView(
            selectedDate: DateTime(2026, 7, 10), // Friday
            records: [
              TimeRecord(
                id: 'r1',
                categoryId: 'work',
                startTime: DateTime(2026, 7, 10, 9),
                endTime: DateTime(2026, 7, 10, 11),
              ),
            ],
            onDayTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('一'), findsOneWidget);
    expect(find.text('二'), findsOneWidget);
    expect(find.text('三'), findsOneWidget);
    expect(find.text('四'), findsOneWidget);
    expect(find.text('五'), findsOneWidget);
    expect(find.text('六'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
    expect(find.text('7/6'), findsOneWidget);
    expect(find.text('7/10'), findsOneWidget);
  });
}