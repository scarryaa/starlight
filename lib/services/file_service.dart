import 'dart:io';
import 'package:flutter/foundation.dart';

class FileService extends ChangeNotifier {
  File? _currentFile;

  File? get currentFile => _currentFile;

  set currentFile(File? file) {
    if (_currentFile != file) {
      _currentFile = file;
      notifyListeners();
    }
  }

  String readFile(String path) {
    return File(path).readAsStringSync();
  }

  void writeFile(String path, String content) {
    File(path).writeAsStringSync(content);
  }

  String getAbsolutePath(String path) {
    return File.fromUri(Uri(path: path)).absolute.path;
  }

  void selectFile(String path) {
    currentFile = File(path);
  }

  List<File> openFiles = [];

  void openFile(String path) {
    File file = File(path);
    if (!openFiles.contains(file)) {
      openFiles.add(file);
      currentFile = file;
      notifyListeners();
    } else {
      currentFile = file;
    }
  }

  void closeFile(String path) {
    File file = File(path);
    openFiles.remove(file);
    if (currentFile == file) {
      currentFile = openFiles.isNotEmpty ? openFiles.last : null;
    }
    notifyListeners();
  }
}
