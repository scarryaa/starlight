import 'package:flutter/material.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeData _lightTheme;
  ThemeData _darkTheme;

  ThemeManager({
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    dynamic initialThemeMode,
  })  : _lightTheme = lightTheme ?? _defaultLightTheme,
        _darkTheme = darkTheme ?? _defaultDarkTheme {
    setThemeMode(initialThemeMode ?? ThemeMode.system);
  }

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => _lightTheme;
  ThemeData get darkTheme => _darkTheme;

  static final ThemeData _defaultLightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue[200]!),
    useMaterial3: true,
  );

  static final ThemeData _defaultDarkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightBlue[200]!,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  void setThemeMode(dynamic mode) {
    if (mode is String) {
      _themeMode = _parseThemeMode(mode);
    } else if (mode is ThemeMode) {
      _themeMode = mode;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setLightTheme(ThemeData theme) {
    _lightTheme = theme;
    notifyListeners();
  }

  void setDarkTheme(ThemeData theme) {
    _darkTheme = theme;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  ThemeData get currentTheme {
    switch (_themeMode) {
      case ThemeMode.system:
        return WidgetsBinding.instance.window.platformBrightness ==
                Brightness.dark
            ? _darkTheme
            : _lightTheme;
      case ThemeMode.light:
        return _lightTheme;
      case ThemeMode.dark:
        return _darkTheme;
    }
  }
}

