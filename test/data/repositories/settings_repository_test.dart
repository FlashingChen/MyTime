import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves and loads complete AI configuration', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository();
    const expected = AppSettings(
      aiBaseUrl: 'https://api.example.com/v1',
      aiApiKey: 'test-key',
      aiModel: 'test-model',
    );

    await repository.save(expected);

    expect(await repository.load(), expected);
  });
}
