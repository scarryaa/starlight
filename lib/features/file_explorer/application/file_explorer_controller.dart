import 'dart:io';

import 'package:flutter/foundation.dart';

class FileExplorerController extends ChangeNotifier {
  Directory? _currentDirectory;
  List<FileTreeItem> _rootItems = [];
  bool _isLoading = false;

  Directory? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  List<FileTreeItem> get rootItems => _rootItems;

  void setDirectory(Directory directory) {
    _currentDirectory = directory;
    _refreshFileTree();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void toggleDirectoryExpansion(FileTreeItem item) {
    if (item.isDirectory) {
      item.isExpanded = !item.isExpanded;
      if (item.isExpanded && item.children.isEmpty) {
        item.children =
            _getDirectoryContents(item.entity as Directory, item.level + 1);
        _sortFileTree(item.children);
      }
      notifyListeners();
    }
  }

  List<FileTreeItem> _getDirectoryContents(Directory directory, int level) {
    List<FileTreeItem> items = [];
    try {
      final entities = directory.listSync();
      for (var entity in entities) {
        final item = FileTreeItem(entity, level, false);
        items.add(item);
      }
    } catch (e) {
      print('Error reading directory contents: $e');
    }
    return items;
  }

  void _refreshFileTree() {
    if (_currentDirectory != null) {
      _rootItems = _getDirectoryContents(_currentDirectory!, 0);
      _sortFileTree(_rootItems);
      notifyListeners();
    }
  }

  void _sortFileTree(List<FileTreeItem> items) {
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
  }
}

class FileTreeItem {
  final FileSystemEntity entity;
  final int level;
  bool isExpanded;
  List<FileTreeItem> children;

  FileTreeItem(this.entity, this.level, this.isExpanded) : children = [];

  bool get isDirectory => entity is Directory;
  String get path => entity.path;
}
