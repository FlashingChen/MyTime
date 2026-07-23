import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/stats/widgets/summary_cards.dart';

void main() {
  testWidgets('shows three cards with values and changes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCards(
            value1: '4h 20m',
            value2: '3h 50m',
            value3: '30m',
            change1: '+12%',
            change2: '-5%',
            change3: '+0%',
          ),
        ),
      ),
    );

    expect(find.text('4h 20m'), findsOneWidget);
    expect(find.text('3h 50m'), findsOneWidget);
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('-5%'), findsOneWidget);
    expect(find.text('+0%'), findsOneWidget);
  });

  testWidgets('positive change shows green, negative shows red', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryCards(
            value1: '1h',
            value2: '1h',
            value3: '1h',
            change1: '+12%',
            change2: '-5%',
            change3: '+0%',
          ),
        ),
      ),
    );

    expect(find.text('+12%'), findsOneWidget);
    expect(find.text('-5%'), findsOneWidget);
  });
}
