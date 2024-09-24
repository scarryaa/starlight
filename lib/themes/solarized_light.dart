import 'package:flutter/material.dart';

final ThemeData solarizedLightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: 'Source Code Pro',
  primaryColor: const Color(0xFF268BD2), // blue
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF268BD2),
    secondary: Color(0xFF2AA198), // cyan
    surface: Color(0xFFFDF6E3), // base2
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF586E75), fontSize: 16), // base01
    bodyMedium: TextStyle(color: Color(0xFF657B83), fontSize: 14), // base00
  ),
  iconTheme: const IconThemeData(color: Color(0xFF268BD2)),
  dividerColor: const Color(0xFFD3AF86), // base1
  scaffoldBackgroundColor: const Color(0xFFEEE8D5),
);
