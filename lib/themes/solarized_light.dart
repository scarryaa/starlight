import 'package:flutter/material.dart';

final ThemeData solarizedLightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: 'Fira Code',
  primaryColor: const Color(0xFF268BD2),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF268BD2),
    secondary: Color(0xFF2AA198),
    tertiary: Color(0xFFCB4B16), // orange for accents
    surface: Color(0xFFFDF6E3),
    background: Color(0xFFEEE8D5),
    error: Color(0xFFDC322F),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF586E75), fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(color: Color(0xFF657B83), fontSize: 14, height: 1.4),
    labelSmall:
        TextStyle(color: Color(0xFF93A1A1), fontSize: 12, letterSpacing: 0.5),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF268BD2), size: 24),
  dividerColor: const Color(0xFFD3AF86),
  scaffoldBackgroundColor: const Color(0xFFEEE8D5),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFEEE8D5),
    foregroundColor: Color(0xFF586E75),
    elevation: 0,
  ),
  cardTheme: CardTheme(
    color: const Color(0xFFFDF6E3),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
