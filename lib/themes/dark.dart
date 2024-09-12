import 'package:flutter/material.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  primaryColor: Colors.blueGrey[900],
  colorScheme: ColorScheme.dark(
    primary: Colors.blueGrey[900]!,
    secondary: Colors.blueGrey[700]!,
    surface: Colors.black,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.grey[300]),
    bodyMedium: TextStyle(color: Colors.grey[400]),
  ),
  iconTheme: IconThemeData(color: Colors.blueGrey[400]),
  dividerColor: Colors.grey[900],
  scaffoldBackgroundColor: Colors.black,
);
