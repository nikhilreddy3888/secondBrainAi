import 'package:flutter/material.dart';

class AppTheme {
  static const actionButtonColor = Color(0xFF7A5C77); // Muted purple/mauve
  static const brandBlueLight = Color(0xFF4A6B99); 
  static const brandBlueDark = Color(0xFF90B0DF); 

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: actionButtonColor,
          brightness: Brightness.light,
          surface: const Color(0xFFFFFFFF),
          surfaceContainer: const Color(0xFFF0F0F4), // Search bg
          outline: const Color(0xFFE5E5EA), // Border color
          onSurface: const Color(0xFF1C1C28), // Primary text
          onSurfaceVariant: const Color(0xFF8E8E93), // Secondary text
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFFF8F8FC),
          foregroundColor: brandBlueLight,
          elevation: 0,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: actionButtonColor,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          surfaceContainer: const Color(0xFF2C2C2C), // Search bg
          outline: const Color(0xFF3A3A3A), // Border color
          onSurface: const Color(0xFFE0E0E0), // Primary text
          onSurfaceVariant: const Color(0xFFA0A0A0), // Secondary text
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Color(0xFF121212),
          foregroundColor: brandBlueDark,
          elevation: 0,
        ),
      );
}
