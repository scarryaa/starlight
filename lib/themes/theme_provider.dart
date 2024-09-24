import 'package:flutter/material.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/themes/light.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/retro.dart';
import 'package:starlight/themes/solarized_dark.dart';
import 'package:starlight/themes/solarized_light.dart';

class ThemeProvider extends ChangeNotifier {
  late final SettingsService _settingsService;

  ThemeProvider(this._settingsService);

  ThemeMode get themeMode => _settingsService.themeMode;
  String get currentTheme => _settingsService.currentTheme;

  ThemeData get currentThemeData {
    switch (currentTheme) {
      case 'light':
        return lightTheme;
      case 'dark':
        return darkTheme;
      case 'retro':
        return retroTerminalTheme;
      case 'solarized_light':
        return solarizedLightTheme;
      case 'solarized_dark':
        return solarizedDarkTheme;
      default:
        return lightTheme;
    }
  }

  void setTheme(String themeName) {
    _settingsService.setTheme(themeName);

    ThemeData selectedTheme = currentThemeData;
    _settingsService.setThemeMode(selectedTheme.brightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark);

    notifyListeners();
  }

  void toggleTheme() {
    _settingsService.setThemeMode(
        themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
    notifyListeners();
  }
}
