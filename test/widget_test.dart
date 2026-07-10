import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/theme/app_theme.dart';

void main() {
  testWidgets('app theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: Text('MyTime'))),
      ),
    );

    expect(find.text('MyTime'), findsOneWidget);
  });
}
