import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/timeline/widgets/timeline_card.dart';

void main() {
  testWidgets('shows uncategorized label for null categoryId', (tester) async {
    final record = TimeRecord(
      id: '1',
      categoryId: null,
      startTime: DateTime(2026, 7, 9, 8, 0),
      endTime: DateTime(2026, 7, 9, 9, 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimelineCard(record: record),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
  });
}
