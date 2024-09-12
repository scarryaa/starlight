import 'package:flutter/foundation.dart';
import 'dart:io';

class FileExplorerController extends ChangeNotifier {
  Directory? _currentDirectory;
  bool _isLoading = false;

  Directory? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;

  void setDirectory(Directory directory) {
    if (_currentDirectory?.path != directory.path) {
      _currentDirectory = directory;
      notifyListeners();
    }
  }

  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
}
