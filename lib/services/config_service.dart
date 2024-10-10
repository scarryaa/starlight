import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';

class ConfigService {
  FileService fileService;
  TabService tabService;
  late String configPath;
  Map<String, dynamic> config = {};
  final ValueNotifier<bool> fileExplorerVisibilityNotifier =
      ValueNotifier(true);

  ConfigService({required this.fileService, required this.tabService}) {
    configPath = _resolveConfigPath();
  }

  void updateConfig(String key, dynamic value) {
    config[key] = value;
    _saveConfig();
    if (key == 'fileExplorerVisible') {
      fileExplorerVisibilityNotifier.value = value;
    }
  }

  void _saveConfig() {
    final configFile = File(configPath);
    final jsonString = jsonEncode(config);
    configFile.writeAsStringSync(jsonString);
  }

  String _resolveConfigPath() {
    final String homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return '$homeDir/.config/starlight/default_config.json';
  }

  void createDefaultConfig() {
    final defaultConfig = {
      'theme': 'light',
      'fontSize': 16,
      'fontFamily': 'ZedMono Nerd Font',
      'initialDirectory': '',
      'tabSize': 4,
      'lineHeight': 1.5,
      'fileExplorerVisible': true,
    };
    File(configPath).createSync(recursive: true);
    File(configPath).writeAsStringSync(json.encode(defaultConfig));
  }

  void loadConfig() {
    try {
      final fileContent = File(configPath).readAsStringSync();
      config = json.decode(fileContent);
      fileExplorerVisibilityNotifier.value =
          config['fileExplorerVisible'] ?? true;
    } catch (e) {
      print('Error loading config: $e');
      // If there's an error loading the config, use default values
      createDefaultConfig();
      loadConfig();
    }
  }

  void saveConfig() {
    config['fileExplorerVisible'] = fileExplorerVisibilityNotifier.value;
    File(configPath).writeAsStringSync(json.encode(config));
  }

  void openConfig() {
    tabService.addTab(configPath.split('/').last, configPath,
        File.fromUri(Uri(path: configPath)).absolute.path);
  }

  void toggleFileExplorerVisibility() {
    fileExplorerVisibilityNotifier.value =
        !fileExplorerVisibilityNotifier.value;
    updateConfig('fileExplorerVisible', fileExplorerVisibilityNotifier.value);
  }
}

