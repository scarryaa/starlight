import 'package:flutter/material.dart';
import 'package:starlight/themes/common.dart';

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  typography: Typography.material2014(),
  primaryColor: primaryBlue,
  colorScheme: ColorScheme.dark(
    primary: primaryBlue,
    secondary: secondaryBlue,
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
  hoverColor: Colors.white.withOpacity(0.1),
  iconTheme: IconThemeData(color: secondaryBlue),
  dividerColor: Colors.grey[900],
  scaffoldBackgroundColor: Colors.black,
);
