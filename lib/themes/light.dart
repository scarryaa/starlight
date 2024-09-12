import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  primaryColor: Colors.blue,
  colorScheme: const ColorScheme.light(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    surface: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey[500],
    foregroundColor: Colors.white,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black54),
  ),
  iconTheme: const IconThemeData(color: Colors.blue),
  dividerColor: Colors.grey[300],
);
