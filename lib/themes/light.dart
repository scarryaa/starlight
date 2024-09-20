import 'package:flutter/material.dart';
import 'package:starlight/themes/common.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  typography: Typography.material2014(),
  fontFamily: 'SF Pro Display',
  primaryColor: primaryBlue,
  colorScheme: ColorScheme.light(
    primary: primaryBlue,
    secondary: secondaryBlue,
    surface: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 2,
    centerTitle: true,
    titleTextStyle: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    actionsIconTheme: IconThemeData(color: primaryBlue),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black54),
  ),
  hoverColor: Colors.black.withOpacity(0.05),
  iconTheme: IconThemeData(color: primaryBlue),
  dividerColor: Colors.grey[300],
  scaffoldBackgroundColor: Colors.white,
);
