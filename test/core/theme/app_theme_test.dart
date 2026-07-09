import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme has correct scaffold background', () {
      final theme = AppTheme.light;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
    });

    test('dark theme has dark scaffold background', () {
      final theme = AppTheme.dark;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF121212));
    });

    test('light theme uses correct primary color', () {
      final theme = AppTheme.light;
      expect(theme.colorScheme.primary, const Color(0xFF6366F1));
    });
  });
}
