import 'package:flutter/material.dart';
import 'package:starlight/services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  late SettingsService _settingsService;

  ThemeProvider(this._settingsService);

  ThemeMode get themeMode => _settingsService.themeMode;

  void toggleTheme() {
    _settingsService.setThemeMode(
        themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
    notifyListeners();
  }
}
