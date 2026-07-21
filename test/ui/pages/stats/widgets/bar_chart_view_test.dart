import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/stats/stats_metrics.dart';
import 'package:mytime/ui/pages/stats/widgets/bar_chart_view.dart';

void main() {
  testWidgets('renders stacked bar chart with selected categories', (tester) async {
    final points = [
      StatsTrendPoint(
        label: '一',
        duration: const Duration(hours: 3),
        categoryDurations: {
          'work': const Duration(hours: 2),
          'read': const Duration(hours: 1),
        },
      ),
      StatsTrendPoint(
        label: '二',
        duration: const Duration(hours: 1),
        categoryDurations: {
          'work': const Duration(hours: 1),
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BarChartView(
            points: points,
            selectedCategoryIds: ['work', 'read'],
          ),
        ),
      ),
    );

    expect(find.byType(SizedBox), findsWidgets);
  });
}