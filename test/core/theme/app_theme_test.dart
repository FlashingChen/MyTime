import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mytime/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme has correct scaffold background', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
    });

    test('dark theme has dark scaffold background', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF121212));
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.surface, const Color(0xFF1E1E1E));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF999999));
      expect(theme.colorScheme.outline, const Color(0xFF2A2A2A));
      expect(theme.bottomSheetTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surface);
      expect(
        theme.bottomNavigationBarTheme.unselectedItemColor,
        theme.colorScheme.onSurfaceVariant,
      );
    });

    test('light theme uses correct primary color', () {
      final theme = AppTheme.light();
      expect(theme.colorScheme.primary, const Color(0xFF6366F1));
    });

    test('accent color is applied to primary color', () {
      final theme = AppTheme.light(accentColor: '#10B981');
      expect(theme.colorScheme.primary, const Color(0xFF10B981));
    });
  });
}
