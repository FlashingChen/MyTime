import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';

void main() {
  test('copyWith can explicitly clear optional secure settings', () {
    const current = AppSettings(
      aiApiKey: 'ai-key',
      aiModel: 'model',
      webDavPassword: 'dav-password',
    );

    final cleared = current.copyWith(
      aiApiKey: null,
      aiModel: null,
      webDavPassword: null,
    );

    expect(cleared.aiApiKey, isNull);
    expect(cleared.aiModel, isNull);
    expect(cleared.webDavPassword, isNull);
  });
}
