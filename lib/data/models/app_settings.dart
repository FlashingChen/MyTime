import 'package:equatable/equatable.dart';

/// User-configurable application settings.
class AppSettings extends Equatable {
  static const Object _unset = Object();

  final String accentColor;
  final String themeMode;
  final String aiBaseUrl;
  final String? aiApiKey;
  final String? aiModel;
  final String webDavEndpoint;
  final String webDavUsername;
  final String? webDavPassword;

  const AppSettings({
    this.accentColor = '#6366F1',
    this.themeMode = 'system',
    this.aiBaseUrl = '',
    this.aiApiKey,
    this.aiModel,
    this.webDavEndpoint = '',
    this.webDavUsername = '',
    this.webDavPassword,
  });

  /// Whether all fields required for an explicit WebDAV sync are present.
  bool get hasWebDavConfiguration {
    final uri = Uri.tryParse(webDavEndpoint);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        webDavUsername.isNotEmpty &&
        (webDavPassword?.isNotEmpty ?? false);
  }

  AppSettings copyWith({
    String? accentColor,
    String? themeMode,
    String? aiBaseUrl,
    Object? aiApiKey = _unset,
    Object? aiModel = _unset,
    String? webDavEndpoint,
    String? webDavUsername,
    Object? webDavPassword = _unset,
  }) {
    return AppSettings(
      accentColor: accentColor ?? this.accentColor,
      themeMode: themeMode ?? this.themeMode,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiApiKey: identical(aiApiKey, _unset)
          ? this.aiApiKey
          : aiApiKey as String?,
      aiModel: identical(aiModel, _unset) ? this.aiModel : aiModel as String?,
      webDavEndpoint: webDavEndpoint ?? this.webDavEndpoint,
      webDavUsername: webDavUsername ?? this.webDavUsername,
      webDavPassword: identical(webDavPassword, _unset)
          ? this.webDavPassword
          : webDavPassword as String?,
    );
  }

  @override
  List<Object?> get props => [
    accentColor,
    themeMode,
    aiBaseUrl,
    aiApiKey,
    aiModel,
    webDavEndpoint,
    webDavUsername,
    webDavPassword,
  ];
}
