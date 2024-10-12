import 'package:flutter/material.dart';
import 'package:starlight/services/config_service.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeData _lightTheme;
  ThemeData _darkTheme;
  final ConfigService _configService;

  ThemeManager({
    required ConfigService configService,
    ThemeData? lightTheme,
    ThemeData? darkTheme,
    dynamic initialThemeMode,
  })  : _configService = configService,
        _lightTheme = lightTheme ?? _defaultLightTheme,
        _darkTheme = darkTheme ?? _defaultDarkTheme {
    setThemeMode(
        initialThemeMode ?? configService.config['theme'] ?? ThemeMode.system);
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
    _saveThemePreference();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveThemePreference();
    notifyListeners();
  }

  void _saveThemePreference() {
    String themeString;
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    _configService.updateConfig('theme', themeString);
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

