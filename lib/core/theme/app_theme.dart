import 'package:flutter/material.dart';
import 'package:mytime/core/constants/app_colors.dart';

/// Light and dark theme definitions for MyTime.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentStart,
        secondary: AppColors.accentEnd,
        surface: AppColors.cardWhite,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -2,
        ),
        titleLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12, color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary, letterSpacing: 0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentStart,
        secondary: AppColors.accentEnd,
        surface: Color(0xFF1E1E1E),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 72, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -2,
        ),
        titleLarge: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
        bodySmall: TextStyle(
          fontSize: 12, color: Color(0xFF999999),
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: Color(0xFF999999), letterSpacing: 0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
      ),
    );
  }
}
