import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _MemorySecureStore secureStore;

  setUp(() {
    secureStore = _MemorySecureStore();
  });

  test('saves and loads complete AI configuration', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(secureStorage: secureStore);
    const expected = AppSettings(
      aiBaseUrl: 'https://api.example.com/v1',
      aiApiKey: 'test-key',
      aiModel: 'test-model',
    );

    await repository.save(expected);

    expect(await repository.load(), expected);
  });

  test('migrates a legacy plaintext API key and removes it', () async {
    SharedPreferences.setMockInitialValues({'ai_api_key': 'legacy-key'});
    final repository = SettingsRepository(secureStorage: secureStore);

    final settings = await repository.load();
    final prefs = await SharedPreferences.getInstance();

    expect(settings.aiApiKey, 'legacy-key');
    expect(await secureStore.read('secure_ai_api_key'), 'legacy-key');
    expect(prefs.containsKey('ai_api_key'), isFalse);
  });

  test(
    'saves WebDAV credentials without putting the password in preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(secureStorage: secureStore);
      const expected = AppSettings(
        webDavEndpoint: 'https://dav.example.com/mytime.json',
        webDavUsername: 'alice',
        webDavPassword: 'dav-secret',
      );

      await repository.save(expected);
      final preferences = await SharedPreferences.getInstance();

      expect(await repository.load(), expected);
      expect(await secureStore.read('secure_webdav_password'), 'dav-secret');
      expect(preferences.containsKey('webdav_password'), isFalse);
    },
  );

  test('rejects an endpoint that embeds WebDAV credentials', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository(secureStorage: secureStore);

    await expectLater(
      repository.save(
        const AppSettings(
          webDavEndpoint: 'https://password@example.com/mytime.json',
          webDavUsername: 'user',
          webDavPassword: 'secret',
        ),
      ),
      throwsArgumentError,
    );

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('webdav_endpoint'), isNull);
    expect(await secureStore.read('secure_webdav_password'), isNull);
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
