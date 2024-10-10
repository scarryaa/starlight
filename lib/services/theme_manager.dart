import 'package:flutter/material.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeData _lightTheme;
  ThemeData _darkTheme;

  ThemeManager({
    ThemeData? lightTheme,
    ThemeData? darkTheme,
  })  : _lightTheme = lightTheme ?? _defaultLightTheme,
        _darkTheme = darkTheme ?? _defaultDarkTheme;

  ThemeMode get themeMode => _themeMode;
  ThemeData get lightTheme => _lightTheme;
  ThemeData get darkTheme => _darkTheme;

  static final ThemeData _defaultLightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    useMaterial3: true,
  );

  static final ThemeData _defaultDarkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setLightTheme(ThemeData theme) {
    _lightTheme = theme;
    notifyListeners();
  }

  void setDarkTheme(ThemeData theme) {
    _darkTheme = theme;
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
