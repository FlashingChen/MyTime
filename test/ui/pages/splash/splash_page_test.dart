import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/ui/pages/splash/splash_page.dart';

void main() {
  group('SplashPage', () {
    testWidgets('renders logo image with correct asset', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/logo/logo.png');
    });

    testWidgets('provides MyTime semantics label', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SplashPage()));

      expect(find.bySemanticsLabel('MyTime 标志'), findsOneWidget);
    });
  });
}
