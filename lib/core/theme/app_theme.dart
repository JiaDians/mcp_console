import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF6750A4);

  // Desktop-optimised text theme — bumps all sizes up ~1–2sp
  static const _textTheme = TextTheme(
    displayLarge:  TextStyle(fontSize: 57),
    displayMedium: TextStyle(fontSize: 45),
    displaySmall:  TextStyle(fontSize: 36),
    headlineLarge:  TextStyle(fontSize: 34),
    headlineMedium: TextStyle(fontSize: 30),
    headlineSmall:  TextStyle(fontSize: 26),
    titleLarge:  TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
    titleSmall:  TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    bodyLarge:   TextStyle(fontSize: 17),
    bodyMedium:  TextStyle(fontSize: 15),
    bodySmall:   TextStyle(fontSize: 13),
    labelLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 13),
    labelSmall:  TextStyle(fontSize: 12),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        chipTheme: const ChipThemeData(
          labelStyle: TextStyle(fontSize: 13),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: _textTheme,
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        chipTheme: const ChipThemeData(
          labelStyle: TextStyle(fontSize: 13),
        ),
      );
}
