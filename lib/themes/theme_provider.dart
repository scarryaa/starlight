import 'package:flutter/material.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/themes/light.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/retro.dart';
import 'package:starlight/themes/solarized_light.dart';
import 'package:starlight/themes/cyberpunk.dart';
import 'package:starlight/themes/minimalist.dart';

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
      case 'solarized':
        return solarizedLightTheme;
      case 'cyberpunk':
        return cyberpunkTheme;
      case 'minimalist':
        return minimalistTheme;
      default:
        return lightTheme;
    }
  }

  void setTheme(String themeName) {
    _settingsService.setTheme(themeName);
    notifyListeners();
  }

  void toggleTheme() {
    _settingsService.setThemeMode(
        themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
    notifyListeners();
  }
}
