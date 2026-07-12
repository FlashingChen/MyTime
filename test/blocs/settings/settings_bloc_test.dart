import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  blocTest<SettingsBloc, SettingsState>(
    'stores all AI configuration fields together',
    setUp: () => SharedPreferences.setMockInitialValues({}),
    build: () =>
        SettingsBloc(SettingsRepository(secureStorage: _MemoryStore())),
    act: (bloc) async {
      bloc.add(const LoadSettings());
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const AiSettingsChanged(
          baseUrl: 'https://api.example.com/v1',
          apiKey: 'key',
          model: 'model',
        ),
      );
    },
    expect: () => [
      const SettingsLoading(),
      const SettingsLoaded(AppSettings()),
      const SettingsLoaded(
        AppSettings(
          aiBaseUrl: 'https://api.example.com/v1',
          aiApiKey: 'key',
          aiModel: 'model',
        ),
      ),
    ],
  );
}

class _MemoryStore implements SecureKeyValueStore {
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
