import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/settings/widgets/color_picker.dart';

void main() {
  testWidgets('shows title and returns selected color', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ColorPickerDialog.show(
                context,
                initialColor: '#6366F1',
              );
            },
            child: const Text('OPEN'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('选择主题色'), findsOneWidget);

    final targetColor = Color(int.parse('10B981', radix: 16) | 0xFF000000);
    await tester.tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == targetColor,
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(result, '#10B981');
  });
}
