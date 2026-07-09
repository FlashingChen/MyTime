import 'package:equatable/equatable.dart';

/// Events for [SettingsBloc].
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Load settings from repository.
class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

/// Change theme mode.
class ThemeModeChanged extends SettingsEvent {
  final String mode;

  const ThemeModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}