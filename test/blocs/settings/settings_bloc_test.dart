import 'dart:async';

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

  blocTest<SettingsBloc, SettingsState>(
    'stores complete WebDAV configuration together',
    setUp: () => SharedPreferences.setMockInitialValues({}),
    build: () =>
        SettingsBloc(SettingsRepository(secureStorage: _MemoryStore())),
    act: (bloc) async {
      bloc.add(const LoadSettings());
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        const WebDavSettingsChanged(
          endpoint: 'https://dav.example.com/mytime.json',
          username: 'alice',
          password: 'secret',
        ),
      );
    },
    expect: () => [
      const SettingsLoading(),
      const SettingsLoaded(AppSettings()),
      const SettingsLoaded(
        AppSettings(
          webDavEndpoint: 'https://dav.example.com/mytime.json',
          webDavUsername: 'alice',
          webDavPassword: 'secret',
        ),
      ),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'surfaces a user-visible state when saving settings fails',
    build: () => SettingsBloc(_FailingSettingsRepository()),
    act: (bloc) async {
      bloc.add(const LoadSettings());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ThemeModeChanged('dark'));
    },
    expect: () => [
      const SettingsLoading(),
      const SettingsLoaded(AppSettings()),
      const SettingsLoaded(AppSettings(), saveErrorMessage: '保存设置失败，请重试'),
    ],
  );

  test(
    'completes a WebDAV save caller with an error when storage fails',
    () async {
      final bloc = SettingsBloc(_FailingSettingsRepository());
      final states = <SettingsState>[];
      final subscription = bloc.stream.listen(states.add);
      bloc.add(const LoadSettings());
      await Future<void>.delayed(Duration.zero);
      final completion = Completer<void>();
      bloc.add(
        WebDavSettingsChanged(
          endpoint: 'https://dav.example.com/mytime.json',
          username: 'alice',
          password: 'secret',
          completion: completion,
        ),
      );

      await expectLater(
        completion.future,
        throwsA(isA<SettingsSaveException>()),
      );
      expect(
        states.last,
        const SettingsLoaded(AppSettings(), saveErrorMessage: '保存设置失败，请重试'),
      );
      await subscription.cancel();
      await bloc.close();
    },
  );

  test(
    'allows a WebDAV save to be retried after a transient storage failure',
    () async {
      final repository = _FailsOnceSettingsRepository();
      final bloc = SettingsBloc(repository);
      bloc.add(const LoadSettings());
      await Future<void>.delayed(Duration.zero);

      final firstAttempt = Completer<void>();
      bloc.add(
        WebDavSettingsChanged(
          endpoint: 'https://dav.example.com/mytime.json',
          username: 'alice',
          password: 'secret',
          completion: firstAttempt,
        ),
      );
      await expectLater(
        firstAttempt.future,
        throwsA(isA<SettingsSaveException>()),
      );

      final retry = Completer<void>();
      bloc.add(
        WebDavSettingsChanged(
          endpoint: 'https://dav.example.com/mytime.json',
          username: 'alice',
          password: 'secret',
          completion: retry,
        ),
      );

      await retry.future;
      expect(repository.saveCalls, 2);
      expect(
        bloc.state,
        const SettingsLoaded(
          AppSettings(
            webDavEndpoint: 'https://dav.example.com/mytime.json',
            webDavUsername: 'alice',
            webDavPassword: 'secret',
          ),
        ),
      );
      await bloc.close();
    },
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

class _FailingSettingsRepository extends SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) {
    throw StateError('storage unavailable');
  }
}

class _FailsOnceSettingsRepository extends SettingsRepository {
  var saveCalls = 0;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    saveCalls += 1;
    if (saveCalls == 1) {
      throw StateError('storage temporarily unavailable');
    }
  }
}
