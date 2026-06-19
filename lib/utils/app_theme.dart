import 'package:flutter/material.dart';

class AppColors {
  static const darkBg      = Color(0xFF0D0D0D);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkCard    = Color(0xFF242424);
  static const darkBorder  = Color(0xFF2E2E2E);
  static const lightBg      = Color(0xFFF5F5F0);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard    = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFE0E0E0);
  static const primary  = Color(0xFFFF6B00);
  static const accent   = Color(0xFF00C2A8);
  static const success  = Color(0xFF22C55E);
  static const danger   = Color(0xFFEF4444);
  static const warning  = Color(0xFFF59E0B);
  static const info     = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(primary: AppColors.primary, secondary: AppColors.accent, surface: AppColors.darkSurface, error: AppColors.danger),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.darkSurface, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
    cardTheme: CardThemeData(color: AppColors.darkCard, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.darkBorder))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: AppColors.darkSurface, selectedItemColor: AppColors.primary, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AppColors.darkSurface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.darkBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.darkBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)), labelStyle: const TextStyle(color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    dividerColor: AppColors.darkBorder, useMaterial3: true,
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(primary: AppColors.primary, secondary: AppColors.accent, surface: AppColors.lightSurface, error: AppColors.danger),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.lightSurface, elevation: 0, iconTheme: IconThemeData(color: Color(0xFF111111))),
    cardTheme: CardThemeData(color: AppColors.lightCard, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.lightBorder))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: AppColors.lightSurface, selectedItemColor: AppColors.primary, unselectedItemColor: Colors.grey, type: BottomNavigationBarType.fixed, elevation: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.lightBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.lightBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)), labelStyle: const TextStyle(color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    dividerColor: AppColors.lightBorder, useMaterial3: true,
  );
}
