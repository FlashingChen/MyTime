import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/category.dart';
import 'package:mytime/ui/pages/stats/widgets/category_filter_sheet.dart';

void main() {
  testWidgets('shows all categories with checkboxes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                    const Category(id: 'rest', name: '休息', color: '#6B7280'),
                  ],
                  selectedIds: ['work', 'read'],
                  onChanged: (_) {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('工作'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('休息'), findsOneWidget);
  });

  testWidgets('tapping unselected category appends it to selection', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                  ],
                  selectedIds: ['work'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // tap '阅读' to add it
    await tester.tap(find.text('阅读').last);
    await tester.pumpAndSettle();

    expect(result, ['work', 'read']);
  });

  testWidgets('tapping selected category removes it (keeping at least one)', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                    const Category(id: 'read', name: '阅读', color: '#8B5CF6'),
                  ],
                  selectedIds: ['work', 'read'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // deselect '工作' — should keep '阅读'
    await tester.tap(find.text('工作').last);
    await tester.pumpAndSettle();

    expect(result, ['read']);
  });

  testWidgets('cannot deselect the last remaining category', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => CategoryFilterSheet(
                  categories: [
                    const Category(id: 'work', name: '工作', color: '#6366F1'),
                  ],
                  selectedIds: ['work'],
                  onChanged: (v) => result = v,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // try to deselect '工作' — should stay selected
    await tester.tap(find.text('工作').last);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
