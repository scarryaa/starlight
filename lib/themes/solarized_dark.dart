import 'package:flutter/material.dart';

final ThemeData solarizedDarkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'Source Code Pro',
  primaryColor: const Color(0xFF268BD2), // blue
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF268BD2), // blue
    secondary: Color(0xFF2AA198), // cyan
    surface: Color(0xFF073642), // base03
    onPrimary: Color(0xFFFDF6E3), // base2
    onSecondary: Color(0xFF93A1A1), // base1
    onSurface: Color(0xFF839496), // base0
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF93A1A1), fontSize: 16), // base1
    bodyMedium: TextStyle(color: Color(0xFF839496), fontSize: 14), // base0
  ),
  iconTheme: const IconThemeData(color: Color(0xFF268BD2)), // blue for icons
  dividerColor: const Color(0xFF586E75), // base01
  scaffoldBackgroundColor: const Color(0xFF002B36), // base03
);
