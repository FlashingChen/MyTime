import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/home/widgets/recent_records_list.dart';

void main() {
  testWidgets('shows uncategorized label for null categoryId', (tester) async {
    final records = [
      TimeRecord(
        id: '1',
        categoryId: null,
        startTime: DateTime(2026, 7, 9, 8, 0),
        endTime: DateTime(2026, 7, 9, 9, 0),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RecentRecordsList(records: records)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
  });
}
