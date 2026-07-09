import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mytime/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('MyTime'), findsOneWidget);
  });
}
