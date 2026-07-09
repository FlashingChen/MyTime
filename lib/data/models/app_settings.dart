import 'package:equatable/equatable.dart';

/// User-configurable application settings.
class AppSettings extends Equatable {
  final String accentColor;
  final String themeMode;
  final String? aiApiKey;
  final String? aiModel;

  const AppSettings({
    this.accentColor = '#6366F1',
    this.themeMode = 'system',
    this.aiApiKey,
    this.aiModel,
  });

  AppSettings copyWith({
    String? accentColor,
    String? themeMode,
    String? aiApiKey,
    String? aiModel,
  }) {
    return AppSettings(
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
    );
  }

  @override
  List<Object?> get props => [accentColor, themeMode, aiApiKey, aiModel];
}
