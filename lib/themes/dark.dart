import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  primaryColor: Colors.blueGrey[700],
  colorScheme: ColorScheme.dark(
    primary: Colors.blueGrey[700]!,
    secondary: Colors.blueGrey[500]!,
    surface: Colors.grey[900]!,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey[800],
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
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.grey[300]),
    bodyMedium: TextStyle(color: Colors.grey[400]),
  ),
  iconTheme: IconThemeData(color: Colors.blueGrey[400]),
  dividerColor: Colors.grey[700],
  scaffoldBackgroundColor: Colors.grey[900],
);
