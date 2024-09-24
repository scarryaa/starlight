import 'package:flutter/material.dart';

final ThemeData retroTerminalTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'VT323', // or any retro-style monospace font
  primaryColor: const Color(0xFF00FF00), // bright green
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00FF00),
    secondary: Color(0xFFFFFF00), // yellow
    surface: Color(0xFF000000),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF00FF00), fontSize: 16),
    bodyMedium: TextStyle(color: Color(0xFF00FF00), fontSize: 14),
  ),
  iconTheme: const IconThemeData(color: Color(0xFF00FF00)),
  dividerColor: const Color(0xFF00FF00),
  scaffoldBackgroundColor: const Color(0xFF000000),
);
