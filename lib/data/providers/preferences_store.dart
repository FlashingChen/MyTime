import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore([Future<SharedPreferences>? preferences])
    : _preferences = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferences;

  Future<SharedPreferences> _freshPreferences() async {
    final preferences = await _preferences;
    await preferences.reload();
    return preferences;
  }

  @override
  Future<String?> getString(String key) async =>
      (await _freshPreferences()).getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await _freshPreferences()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await _freshPreferences()).remove(key);
}
