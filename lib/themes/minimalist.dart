import 'package:flutter/material.dart';

final ThemeData minimalistTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  fontFamily: 'Roboto',
  primaryColor: Colors.black,
  colorScheme: ColorScheme.light(
    primary: Colors.black,
    secondary: Colors.grey[600]!,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black54, fontSize: 14),
  ),
  iconTheme: const IconThemeData(color: Colors.black),
  dividerColor: Colors.grey[300],
  scaffoldBackgroundColor: Colors.white,
);
