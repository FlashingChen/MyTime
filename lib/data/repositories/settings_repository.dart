import 'package:mytime/data/models/app_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mytime/data/providers/preferences_store.dart';

/// Minimal secure key-value boundary used for sensitive application settings.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

/// Repository for app settings persistence.
class SettingsRepository {
  static const _legacyAiApiKey = 'ai_api_key';
  static const _secureAiApiKey = 'secure_ai_api_key';
  static const _webDavEndpoint = 'webdav_endpoint';
  static const _webDavUsername = 'webdav_username';
  static const _secureWebDavPassword = 'secure_webdav_password';
  static const _reminderEnabled = 'reminder_enabled';
  static const _reminderIntervalMinutes = 'reminder_interval_minutes';

  /// Default interval between timer reminders, in minutes.
  static const defaultReminderIntervalMinutes = 30;

  SettingsRepository({
    SecureKeyValueStore? secureStorage,
    PreferencesStore? preferences,
  }) : _secureStorage = secureStorage ?? FlutterSecureKeyValueStore(),
       _preferences = preferences ?? SharedPreferencesStore();

  final SecureKeyValueStore _secureStorage;
  final PreferencesStore _preferences;

  Future<AppSettings> load() async {
    var apiKey = await _secureStorage.read(_secureAiApiKey);
    final webDavPassword = await _secureStorage.read(_secureWebDavPassword);
    final legacyApiKey = await _preferences.getString(_legacyAiApiKey);
    if (apiKey == null && legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await _secureStorage.write(_secureAiApiKey, legacyApiKey);
      await _preferences.remove(_legacyAiApiKey);
      apiKey = legacyApiKey;
    }
    return AppSettings(
      accentColor: await _preferences.getString('accent_color') ?? '#6366F1',
      themeMode: await _preferences.getString('theme_mode') ?? 'system',
      aiBaseUrl: await _preferences.getString('ai_base_url') ?? '',
      aiApiKey: apiKey,
      aiModel: await _preferences.getString('ai_model'),
      webDavEndpoint: await _preferences.getString(_webDavEndpoint) ?? '',
      webDavUsername: await _preferences.getString(_webDavUsername) ?? '',
      webDavPassword: webDavPassword,
      reminderEnabled: await _preferences.getString(_reminderEnabled) == 'true',
      reminderIntervalMinutes:
          int.tryParse(
            await _preferences.getString(_reminderIntervalMinutes) ?? '',
          ) ??
          defaultReminderIntervalMinutes,
    );
  }

  Future<void> save(AppSettings settings) async {
    _validateWebDavEndpoint(settings);
    await _preferences.setString('accent_color', settings.accentColor);
    await _preferences.setString('theme_mode', settings.themeMode);
    await _preferences.setString('ai_base_url', settings.aiBaseUrl);
    if (settings.aiApiKey != null && settings.aiApiKey!.isNotEmpty) {
      await _secureStorage.write(_secureAiApiKey, settings.aiApiKey!);
    } else {
      await _secureStorage.delete(_secureAiApiKey);
    }
    await _preferences.remove(_legacyAiApiKey);
    if (settings.aiModel != null) {
      await _preferences.setString('ai_model', settings.aiModel!);
    } else {
      await _preferences.remove('ai_model');
    }
    await _preferences.setString(_webDavEndpoint, settings.webDavEndpoint);
    await _preferences.setString(_webDavUsername, settings.webDavUsername);
    await _preferences.setString(
      _reminderEnabled,
      settings.reminderEnabled ? 'true' : 'false',
    );
    await _preferences.setString(
      _reminderIntervalMinutes,
      '${settings.reminderIntervalMinutes}',
    );
    if (settings.webDavPassword != null &&
        settings.webDavPassword!.isNotEmpty) {
      await _secureStorage.write(
        _secureWebDavPassword,
        settings.webDavPassword!,
      );
    } else {
      await _secureStorage.delete(_secureWebDavPassword);
    }
  }

  void _validateWebDavEndpoint(AppSettings settings) {
    final endpoint = settings.webDavEndpoint.trim();
    if (endpoint.isEmpty) {
      if (settings.webDavUsername.isNotEmpty ||
          (settings.webDavPassword?.isNotEmpty ?? false)) {
        throw ArgumentError('WebDAV credentials require an HTTPS endpoint');
      }
      return;
    }
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        settings.webDavEndpoint,
        'webDavEndpoint',
        'must be an HTTPS URL without embedded credentials',
      );
    }
  }
}
