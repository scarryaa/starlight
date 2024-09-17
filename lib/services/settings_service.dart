import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool _showFileExplorer = true;
  bool _showTerminal = false;
  bool _isFileExplorerOnLeft = true;
  double _windowWidth = 700;
  double _windowHeight = 600;
  bool _isFullscreen = false;
  ThemeMode _themeMode = ThemeMode.system;

  bool get showFileExplorer => _showFileExplorer;
  bool get showTerminal => _showTerminal;
  bool get isFileExplorerOnLeft => _isFileExplorerOnLeft;
  double get windowWidth => _windowWidth;
  double get windowHeight => _windowHeight;
  bool get isFullscreen => _isFullscreen;
  ThemeMode get themeMode => _themeMode;

  SettingsService() {
    _loadSettings();
  }

  Future<void> init() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _showFileExplorer = _prefs.getBool('showFileExplorer') ?? true;
    _showTerminal = _prefs.getBool('showTerminal') ?? false;
    _isFileExplorerOnLeft = _prefs.getBool('isFileExplorerOnLeft') ?? true;
    _windowWidth = _prefs.getDouble('windowWidth') ?? 700;
    _windowHeight = _prefs.getDouble('windowHeight') ?? 600;
    _isFullscreen = _prefs.getBool('isFullscreen') ?? false;
    _themeMode =
        ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _prefs.setBool('showFileExplorer', _showFileExplorer);
    await _prefs.setBool('showTerminal', _showTerminal);
    await _prefs.setBool('isFileExplorerOnLeft', _isFileExplorerOnLeft);
    await _prefs.setDouble('windowWidth', _windowWidth);
    await _prefs.setDouble('windowHeight', _windowHeight);
    await _prefs.setBool('isFullscreen', _isFullscreen);
    await _prefs.setInt('themeMode', _themeMode.index);
  }

  void setShowFileExplorer(bool value) {
    _showFileExplorer = value;
    saveSettings();
    notifyListeners();
  }

  void setShowTerminal(bool value) {
    _showTerminal = value;
    saveSettings();
    notifyListeners();
  }

  void setIsFileExplorerOnLeft(bool value) {
    _isFileExplorerOnLeft = value;
    saveSettings();
    notifyListeners();
  }

  void setWindowSize(Size size) {
    _windowWidth = size.width;
    _windowHeight = size.height;
    saveSettings();
    notifyListeners();
  }

  void setFullscreen(bool value) {
    _isFullscreen = value;
    saveSettings();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    saveSettings();
    notifyListeners();
  }
}
