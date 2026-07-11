import 'package:equatable/equatable.dart';

/// User-configurable application settings.
class AppSettings extends Equatable {
  final String accentColor;
  final String themeMode;
  final String aiBaseUrl;
  final String? aiApiKey;
  final String? aiModel;

  const AppSettings({
    this.accentColor = '#6366F1',
    this.themeMode = 'system',
    this.aiBaseUrl = '',
    this.aiApiKey,
    this.aiModel,
  });

  AppSettings copyWith({
    String? accentColor,
    String? themeMode,
    String? aiBaseUrl,
    String? aiApiKey,
    String? aiModel,
  }) {
    return AppSettings(
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
    );
  }

  @override
  List<Object?> get props => [
    accentColor,
    themeMode,
    aiBaseUrl,
    aiApiKey,
    aiModel,
  ];
}
