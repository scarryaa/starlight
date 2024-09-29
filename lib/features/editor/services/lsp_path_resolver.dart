import 'dart:io';

class LspPathResolver {
  static String? _flutterSdkPath;
  static String? _pythonPath;
  static String? _nodeJsPath;

  static Future<void> initialize() async {
    _flutterSdkPath = await _findFlutterSdkPath();
    _pythonPath = await _findPythonPath();
    _nodeJsPath = await _findNodeJsPath();
  }

  static Future<String?> _findFlutterSdkPath() async {
    // First, check if FLUTTER_ROOT environment variable is set
    var flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && await Directory(flutterRoot).exists()) {
      return flutterRoot;
    }

    // If not, try to find Flutter using 'which' command
    var result = await Process.run('which', ['flutter']);
    if (result.exitCode == 0) {
      String flutterPath = result.stdout.toString().trim();
      return Directory(flutterPath).parent.parent.path;
    }

    // If still not found, try common installation locations
    List<String> possiblePaths = [
      '/usr/local/flutter',
      '${Platform.environment['HOME']}/flutter',
      'C:\\flutter',
    ];

    for (var path in possiblePaths) {
      if (await Directory(path).exists()) {
        return path;
      }
    }

    print(
        "Flutter SDK not found. Please ensure it's installed and in your PATH.");
    return null;
  }

  static Future<String?> _findPythonPath() async {
    var result = await Process.run('which', ['python3']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    print("Python not found. Please ensure it's installed and in your PATH.");
    return null;
  }

  static Future<String?> _findNodeJsPath() async {
    var result = await Process.run('which', ['node']);
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    print("Node.js not found. Please ensure it's installed and in your PATH.");
    return null;
  }

  static String? resolveLspPath(String languageId) {
    switch (languageId) {
      case 'dart':
        return _flutterSdkPath != null ? '$_flutterSdkPath/bin/dart' : null;
      case 'python':
        return _pythonPath;
      case 'javascript':
      case 'typescript':
        return _nodeJsPath != null ? 'typescript-language-server' : null;
      default:
        return null;
    }
  }
}
