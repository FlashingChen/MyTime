import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/home/widgets/timer_circle.dart';

void main() {
  testWidgets('clamps a negative duration to 00:00', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimerCircle(duration: Duration(seconds: -7199), progress: 0),
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
  });
}
