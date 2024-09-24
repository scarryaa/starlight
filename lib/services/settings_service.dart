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
  String _currentTheme = 'light';
  static const String lastDirectoryKey = 'last_directory';
  bool _hideSystemFiles = true;

  // Private constructor
  SettingsService._();

  // Singleton instance
  static SettingsService? _instance;
  factory SettingsService() {
    _instance ??= SettingsService._();
    return _instance!;
  }

  bool get showFileExplorer => _showFileExplorer;
  bool get showTerminal => _showTerminal;
  bool get isFileExplorerOnLeft => _isFileExplorerOnLeft;
  double get windowWidth => _windowWidth;
  double get windowHeight => _windowHeight;
  bool get isFullscreen => _isFullscreen;
  ThemeMode get themeMode => _themeMode;
  String get currentTheme => _currentTheme;
  bool get hideSystemFiles => _hideSystemFiles;

  // Initialize the service
  Future<SettingsService> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    return this;
  }

  Future<void> _loadSettings() async {
    _showFileExplorer = _prefs.getBool('showFileExplorer') ?? true;
    _showTerminal = _prefs.getBool('showTerminal') ?? false;
    _isFileExplorerOnLeft = _prefs.getBool('isFileExplorerOnLeft') ?? true;
    _windowWidth = _prefs.getDouble('windowWidth') ?? 700;
    _windowHeight = _prefs.getDouble('windowHeight') ?? 600;
    _isFullscreen = _prefs.getBool('isFullscreen') ?? false;
    _themeMode =
        ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
    _currentTheme = _prefs.getString('currentTheme') ?? 'light';
    _hideSystemFiles = _prefs.getBool('hideSystemFiles') ?? true;
    notifyListeners();
  }

  Future<void> setLastDirectory(String directory) async {
    await _prefs.setString(lastDirectoryKey, directory);
  }

  String? getLastDirectory() {
    return _prefs.getString(lastDirectoryKey);
  }

  Future<void> saveSettings() async {
    await _prefs.setBool('showFileExplorer', _showFileExplorer);
    await _prefs.setBool('showTerminal', _showTerminal);
    await _prefs.setBool('isFileExplorerOnLeft', _isFileExplorerOnLeft);
    await _prefs.setDouble('windowWidth', _windowWidth);
    await _prefs.setDouble('windowHeight', _windowHeight);
    await _prefs.setBool('isFullscreen', _isFullscreen);
    await _prefs.setInt('themeMode', _themeMode.index);
    await _prefs.setString('currentTheme', _currentTheme);
    await _prefs.setBool('hideSystemFiles', _hideSystemFiles);
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

  void setTheme(String themeName) {
    _currentTheme = themeName;
    saveSettings();
    notifyListeners();
  }

  void setHideSystemFiles(bool value) {
    _hideSystemFiles = value;
    saveSettings();
    notifyListeners();
  }
}
