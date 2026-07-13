import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/repositories/settings_repository.dart';

/// BLoC for managing application settings.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repository;

  SettingsBloc(this._repository) : super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<AccentColorChanged>(_onAccentColorChanged);
    on<AiSettingsChanged>(_onAiSettingsChanged);
    on<WebDavSettingsChanged>(_onWebDavSettingsChanged);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());
    try {
      final settings = await _repository.load();
      emit(SettingsLoaded(settings));
    } catch (_) {
      emit(const SettingsError('读取设置失败，请重试'));
    }
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      final updated = current.copyWith(themeMode: event.mode);
      await _save(updated, emit);
    }
  }

  Future<void> _onAccentColorChanged(
    AccentColorChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      final updated = current.copyWith(accentColor: event.color);
      await _save(updated, emit);
    }
  }

  Future<void> _onAiSettingsChanged(
    AiSettingsChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      final updated = current.copyWith(
        aiBaseUrl: event.baseUrl,
        aiApiKey: event.apiKey,
        aiModel: event.model,
      );
      await _save(updated, emit);
    }
  }

  Future<void> _onWebDavSettingsChanged(
    WebDavSettingsChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (state is! SettingsLoaded) {
      event.completion?.completeError(const SettingsSaveException());
      return;
    }
    final current = (state as SettingsLoaded).settings;
    final updated = current.copyWith(
      webDavEndpoint: event.endpoint,
      webDavUsername: event.username,
      webDavPassword: event.password,
    );
    await _save(updated, emit, event.completion);
  }

  Future<void> _save(
    AppSettings settings,
    Emitter<SettingsState> emit, [
    Completer<void>? completion,
  ]) async {
    try {
      await _repository.save(settings);
      emit(SettingsLoaded(settings));
      completion?.complete();
    } catch (_) {
      emit(const SettingsError('保存设置失败，请重试'));
      completion?.completeError(const SettingsSaveException());
    }
  }
}

/// Indicates that a settings write did not complete successfully.
class SettingsSaveException implements Exception {
  const SettingsSaveException();
}
