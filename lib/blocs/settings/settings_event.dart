import 'dart:async';

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

/// Change accent color.
class AccentColorChanged extends SettingsEvent {
  final String color;

  const AccentColorChanged(this.color);

  @override
  List<Object?> get props => [color];
}

/// Change the saved OpenAI-compatible model configuration.
class AiSettingsChanged extends SettingsEvent {
  final String baseUrl;
  final String apiKey;
  final String model;

  const AiSettingsChanged({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  @override
  List<Object?> get props => [baseUrl, apiKey, model];
}

/// Changes the saved WebDAV endpoint and credentials.
class WebDavSettingsChanged extends SettingsEvent {
  const WebDavSettingsChanged({
    required this.endpoint,
    required this.username,
    required this.password,
    this.completion,
  });

  final String endpoint;
  final String username;
  final String password;
  final Completer<void>? completion;

  @override
  List<Object?> get props => [endpoint, username, password];
}

/// Changes the timer reminder configuration.
class ReminderSettingsChanged extends SettingsEvent {
  const ReminderSettingsChanged({
    required this.enabled,
    required this.intervalMinutes,
  });

  final bool enabled;
  final int intervalMinutes;

  @override
  List<Object?> get props => [enabled, intervalMinutes];
}
