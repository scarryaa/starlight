import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FileExplorerController extends ChangeNotifier {
  Directory? _currentDirectory;
  List<FileTreeItem> _rootItems = [];
  bool _isLoading = false;
  FileTreeItem? _cutItem;
  FileTreeItem? _copiedItem;

  Directory? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  List<FileTreeItem> get rootItems => _rootItems;

  void setDirectory(Directory directory) {
    _currentDirectory = directory;
    _refreshFileTree();
  }

  Future<void> createFile(String parentPath, String fileName) async {
    final newFile = File('$parentPath/$fileName');
    await newFile.create();
    await refreshDirectory();
  }

  Future<void> createFolder(String parentPath, String folderName) async {
    final newFolder = Directory('$parentPath/$folderName');
    await newFolder.create();
    await refreshDirectory();
  }

  Future<void> rename(String oldPath, String newName) async {
    final oldFile =
        FileSystemEntity.typeSync(oldPath) == FileSystemEntityType.directory
            ? Directory(oldPath)
            : File(oldPath);
    final newPath = '${oldFile.parent.path}/$newName';
    await oldFile.rename(newPath);
    await refreshDirectory();
  }

  Future<void> delete(String path) async {
    final fileOrDir =
        FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
            ? Directory(path)
            : File(path);
    await fileOrDir.delete(recursive: true);
    await refreshDirectory();
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

  Future<void> refreshDirectory() async {
    if (_currentDirectory != null) {
      _rootItems = _getDirectoryContents(_currentDirectory!, 0);
      _sortFileTree(_rootItems);
      notifyListeners();
    }
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

  void setCutItem(FileTreeItem item) {
    _cutItem = item;
    _copiedItem = null;
  }

  void setCopiedItem(FileTreeItem item) {
    _copiedItem = item;
    _cutItem = null;
  }

  Future<void> pasteItem(String destinationPath) async {
    if (_cutItem == null && _copiedItem == null) {
      throw Exception('No item to paste');
    }

    final itemToPaste = _cutItem ?? _copiedItem!;
    final newPath = path.join(destinationPath, itemToPaste.name);

    if (_cutItem != null) {
      await _moveItem(itemToPaste.path, newPath);
      _cutItem = null;
    } else {
      await _copyItem(itemToPaste.path, newPath);
    }
  }

  Future<void> _moveItem(String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    final destinationFile = File(destinationPath);

    if (await sourceFile.exists()) {
      await sourceFile.rename(destinationPath);
    } else {
      final sourceDir = Directory(sourcePath);
      await sourceDir.rename(destinationPath);
    }
  }

  Future<void> _copyItem(String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    final destinationFile = File(destinationPath);

    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
    } else {
      final sourceDir = Directory(sourcePath);
      await _copyDirectory(sourceDir, Directory(destinationPath));
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory =
            Directory(path.join(destination.path, path.basename(entity.path)));
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity
            .copy(path.join(destination.path, path.basename(entity.path)));
      }
    }
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
  String get name => path.split('/').last;
}
