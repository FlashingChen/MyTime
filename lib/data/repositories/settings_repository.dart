import 'package:mytime/data/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for app settings persistence.
class SettingsRepository {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final prefs = await _prefs;
    return AppSettings(
      accentColor: prefs.getString('accent_color') ?? '#6366F1',
      themeMode: prefs.getString('theme_mode') ?? 'system',
      aiApiKey: prefs.getString('ai_api_key'),
      aiModel: prefs.getString('ai_model'),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString('accent_color', settings.accentColor);
    await prefs.setString('theme_mode', settings.themeMode);
    if (settings.aiApiKey != null) await prefs.setString('ai_api_key', settings.aiApiKey!);
    if (settings.aiModel != null) await prefs.setString('ai_model', settings.aiModel!);
  }
}