import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/time_record.dart';
import 'package:mytime/ui/pages/stats/widgets/ai_insight_view.dart';

void main() {
  testWidgets('regenerates a different simulated suggestion', (tester) async {
    final start = DateTime(2026, 7, 10, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiInsightView(
            periodLabel: '本周',
            records: [
              TimeRecord(
                id: 'work',
                categoryId: 'work',
                startTime: start,
                endTime: start.add(const Duration(hours: 3)),
              ),
              TimeRecord(
                id: 'break',
                categoryId: 'rest',
                startTime: start.add(const Duration(hours: 4)),
                endTime: start.add(const Duration(minutes: 30)),
              ),
            ],
          ),
        ),
      ),
    );

    final firstSuggestion = tester
        .widget<Text>(find.byKey(const ValueKey('ai-suggestion-0')))
        .data;

    await tester.tap(find.text('重新生成建议'));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('ai-suggestion-0'))).data,
      isNot(firstSuggestion),
    );
  });
}
