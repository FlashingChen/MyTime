import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Light and dark theme definitions for MyTime.
class AppTheme {
  AppTheme._();

  static Color _accent(String? accentColor) {
    const fallback = '#6366F1';
    final value = int.tryParse(
      (accentColor ?? fallback).replaceFirst('#', '0xFF'),
    );
    return value != null ? Color(value) : AppColors.accentStart;
  }

  static ThemeData light({String? accentColor}) => _theme(
    scheme: ColorScheme.light(
      primary: _accent(accentColor),
      secondary: AppColors.accentEnd,
      surface: AppColors.cardWhite,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
      surfaceContainerHighest: const Color(0xFFF0F0F0),
    ),
    scaffoldBackground: AppColors.backgroundLight,
  );

  static ThemeData dark({String? accentColor}) => _theme(
    scheme: ColorScheme.dark(
      primary: _accent(accentColor),
      secondary: AppColors.accentEnd,
      surface: const Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFF999999),
      outline: const Color(0xFF2A2A2A),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
    ),
    scaffoldBackground: const Color(0xFF121212),
  );

  static ThemeData _theme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -2,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(scheme.onPrimary),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      splashColor: isDark ? Colors.white.withValues(alpha: 0.06) : null,
    );
  }
}
