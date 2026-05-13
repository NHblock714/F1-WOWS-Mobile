import 'package:flutter/material.dart';

class AppColors {
  static const bgDark = Color(0xFF0E1A2E);
  static const bgPanel = Color(0xFF16243F);
  static const bgCard = Color(0xFF1B2D4A);
  static const bgHover = Color(0xFF26406B);
  static const border = Color(0xFF2B3E5C);
  static const text = Color(0xFFF0F0F0);
  static const textDim = Color(0xFF9CABC0);
  static const textFaded = Color(0xFF6A7383);

  static const gold = Color(0xFFFFD700);
  static const goldDeep = Color(0xFFDAA520);
  static const green = Color(0xFF7FE070);
  static const blue = Color(0xFF5DADE2);
  static const red = Color(0xFFE74C3C);
  static const orange = Color(0xFFF39C12);
  static const purple = Color(0xFF9759BC);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.goldDeep,
      surface: AppColors.bgPanel,
      onSurface: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgPanel,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.goldDeep,
        foregroundColor: const Color(0xFF1A1A1A),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.goldDeep, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.text),
      bodyMedium: TextStyle(color: AppColors.text),
      bodySmall: TextStyle(color: AppColors.textDim),
    ),
  );
}
