import 'dart:io';

import 'package:flutter/foundation.dart';

class FileExplorerController extends ChangeNotifier {
  Directory? _currentDirectory;
  final List<FileTreeItem> _fileTree = [];
  bool _isLoading = false;

  Directory? get currentDirectory => _currentDirectory;
  List<FileTreeItem> get fileTree => _fileTree;
  bool get isLoading => _isLoading;

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
      final index = _fileTree.indexOf(item);
      if (index != -1) {
        item.isExpanded = !item.isExpanded;
        if (item.isExpanded) {
          final subItems =
              _getSubItems(item.entity as Directory, item.level + 1);
          _fileTree.insertAll(index + 1, subItems);
          _sortFileTree(); // Re-sort after adding new items
        } else {
          _removeSubItems(index + 1, item.level);
        }
        notifyListeners();
      }
    }
  }

  void _addDirectoryContents(Directory directory, int level) {
    final entities = directory.listSync();
    for (var entity in entities) {
      _fileTree.add(FileTreeItem(entity, level, false));
    }
  }

  List<FileTreeItem> _getSubItems(Directory directory, int level) {
    List<FileTreeItem> subItems = [];
    final entities = directory.listSync();
    for (var entity in entities) {
      subItems.add(FileTreeItem(entity, level, false));
    }
    return subItems;
  }

  void _refreshFileTree() {
    _fileTree.clear();
    _addDirectoryContents(_currentDirectory!, 0);
    _sortFileTree();
    notifyListeners();
  }

  void _removeSubItems(int startIndex, int parentLevel) {
    while (startIndex < _fileTree.length &&
        _fileTree[startIndex].level > parentLevel) {
      _fileTree.removeAt(startIndex);
    }
  }

  void _sortFileTree() {
    _fileTree.sort((a, b) {
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

  FileTreeItem(this.entity, this.level, this.isExpanded);

  bool get isDirectory => entity is Directory;
  String get path => entity.path;
}
