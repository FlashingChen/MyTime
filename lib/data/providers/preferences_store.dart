import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesStore implements PreferencesStore {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();
  @override
  Future<String?> getString(String key) async =>
      (await _preferences).getString(key);
  @override
  Future<void> setString(String key, String value) async {
    await (await _preferences).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _preferences).remove(key);
  }
}
