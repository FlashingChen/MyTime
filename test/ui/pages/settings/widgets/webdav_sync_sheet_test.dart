import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/ui/pages/settings/widgets/webdav_sync_sheet.dart';

void main() {
  testWidgets('renders WebDAV configuration and manual sync actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WebDavSyncSheet(settings: AppSettings())),
      ),
    );

    expect(find.text('WebDAV 同步'), findsOneWidget);
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('保存配置'), findsOneWidget);
    expect(find.text('立即同步'), findsOneWidget);
  });
}
