import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/settings/widgets/data_exchange_sheet.dart';

void main() {
  testWidgets('renders the import and export actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DataExchangeSheet())),
    );

    expect(find.text('数据导入导出'), findsOneWidget);
    expect(find.text('导出 JSON 文件'), findsOneWidget);
    expect(find.text('从剪贴板导入 JSON'), findsOneWidget);
  });
}
