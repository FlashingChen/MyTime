import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/splash/splash_page.dart';

void main() {
  group('SplashPage', () {
    testWidgets('renders SvgPicture in light mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashPage()),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svgPicture.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, contains('logo.svg'));
      expect(find.bySemanticsLabel('MyTime 标志'), findsOneWidget);
    });

    testWidgets('uses dark logo in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const SplashPage(),
        ),
      );

      final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
      final loader = svgPicture.bytesLoader as SvgAssetLoader;
      expect(loader.assetName, contains('logo_dark.svg'));
    });
  });
}
