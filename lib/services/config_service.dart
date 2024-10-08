import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';

class ConfigService {
  FileService fileService;
  TabService tabService;
  late String configPath;

  ConfigService({required this.fileService, required this.tabService}) {
    configPath = _resolveConfigPath();
  }

  String _resolveConfigPath() {
    final String homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return path.join(homeDir, '.config', 'starlight', 'default_config.json');
  }

  void openConfig() {
    if (!File(configPath).existsSync()) {
      File(configPath).createSync(recursive: true);
      File(configPath).writeAsStringSync('{}');
    }
    tabService.addTab(configPath);
  }
}
