import 'package:equatable/equatable.dart';
import 'package:mytime/data/models/app_settings.dart';

/// States for [SettingsBloc].
abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any load.
class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

/// Loading settings.
class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

/// Settings loaded successfully.
class SettingsLoaded extends SettingsState {
  final AppSettings settings;

  const SettingsLoaded(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Error loading settings.
class SettingsError extends SettingsState {
  final String message;

  const SettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
