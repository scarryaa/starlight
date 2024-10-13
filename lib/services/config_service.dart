import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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
    } else if (key == "theme") {}
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
      'windowSize': {'width': 700.0, 'height': 600.0},
      'windowPosition': {'left': 0.0, 'top': 0.0},
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

  void saveWindowSize(Size size) {
    updateConfig('windowSize', {'width': size.width, 'height': size.height});
  }

  void saveWindowPosition(Offset position) {
    updateConfig('windowPosition', {'left': position.dx, 'top': position.dy});
  }

  Size getWindowSize() {
    final sizeMap = config['windowSize'] as Map<String, dynamic>?;
    return sizeMap != null
        ? Size(sizeMap['width'].toDouble(), sizeMap['height'].toDouble())
        : const Size(700, 600);
  }

  Offset getWindowPosition() {
    final positionMap = config['windowPosition'] as Map<String, dynamic>?;
    return positionMap != null
        ? Offset(positionMap['left'].toDouble(), positionMap['top'].toDouble())
        : Offset.zero;
  }
}
