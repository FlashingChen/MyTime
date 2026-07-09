import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_state.dart';
import 'package:mytime/data/repositories/settings_repository.dart';

/// BLoC for managing application settings.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository _repository;

  SettingsBloc(this._repository) : super(const SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ThemeModeChanged>(_onThemeModeChanged);
  }

  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(const SettingsLoading());
    try {
      final settings = await _repository.load();
      emit(SettingsLoaded(settings));
    } catch (e) {
      emit(const SettingsError('Failed to load settings'));
    }
  }

  Future<void> _onThemeModeChanged(ThemeModeChanged event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      final current = (state as SettingsLoaded).settings;
      final updated = current.copyWith(themeMode: event.mode);
      await _repository.save(updated);
      emit(SettingsLoaded(updated));
    }
  }
}