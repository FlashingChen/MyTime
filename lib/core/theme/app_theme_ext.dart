import 'package:flutter/material.dart';

/// Theme shortcuts shared by MyTime widgets.
extension AppThemeContext on BuildContext {
  /// The active semantic color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Whether the active application theme is dark.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
