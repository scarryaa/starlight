import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';

class FileExplorerController extends ChangeNotifier {
  Directory? _currentDirectory;
  List<FileTreeItem> _rootItems = [];
  bool _isLoading = false;
  List<FileTreeItem> _cutItems = [];
  List<FileTreeItem> _copiedItems = [];
  FileTreeItem? _selectedItem;
  final Set<FileTreeItem> _selectedItems = {};
  bool _isMultiSelectMode = false;

  // Getters
  Directory? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  bool get isMultiSelectMode => _isMultiSelectMode;
  List<FileTreeItem> get rootItems => _rootItems;
  FileTreeItem? get selectedItem => _selectedItem;
  List<FileTreeItem> get selectedItems => _selectedItems.toList();

  // File operations
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

  Future<void> delete(String path) async {
    final fileOrDir =
        FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
            ? Directory(path)
            : File(path);
    await fileOrDir.delete(recursive: true);
    await refreshDirectory();
  }

  void enterMultiSelectMode() {
    _isMultiSelectMode = true;
    notifyListeners();
  }

  void exitMultiSelectMode() {
    _isMultiSelectMode = false;
    _selectedItems.clear();
    notifyListeners();
  }

  FileTreeItem? findTappedItem(Offset position, List<FileTreeItem> items) {
    for (var item in items) {
      if (_isPositionInItem(position, item)) {
        return item;
      }
      if (item.isDirectory && item.isExpanded) {
        final tappedChild = findTappedItem(position, item.children);
        if (tappedChild != null) {
          return tappedChild;
        }
      }
    }
    return null;
  }

  Future<List<FileOperation>> pasteItems(String destinationPath) async {
    final itemsToPaste = _cutItems.isNotEmpty ? _cutItems : _copiedItems;
    final isCutOperation = _cutItems.isNotEmpty;
    List<FileOperation> operations = [];

    for (var item in itemsToPaste) {
      final newPath = isCutOperation
          ? path.join(destinationPath, item.name)
          : _generateUniquePathIfNeeded(destinationPath, item.name);

      if (isCutOperation) {
        await moveItem(item.path, newPath);
        operations.add(FileOperation(OperationType.move, item.path, newPath));
      } else {
        await copyItem(item.path, newPath);
        operations.add(FileOperation(OperationType.copy, item.path, newPath));
      }
    }

    _cutItems.clear();
    _copiedItems.clear();
    notifyListeners();

    return operations;
  }

  Future<void> toggleDirectoryExpansion(FileTreeItem item) async {
    if (item.isDirectory) {
      item.isExpanded = !item.isExpanded;
      if (item.isExpanded && item.children.isEmpty) {
        item.children = await _getDirectoryContents(
            Directory(item.path), item.level + 1, item);
      }
      notifyListeners();
    }
  }

  Future<void> moveItem(String sourcePath, String destinationPath) async {
    final source =
        FileSystemEntity.typeSync(sourcePath) == FileSystemEntityType.directory
            ? Directory(sourcePath)
            : File(sourcePath);

    try {
      await source.rename(destinationPath);
    } catch (e) {
      // If rename fails (e.g., across devices), fallback to copy and delete
      await _copyItem(sourcePath, destinationPath);
      await source.delete(recursive: true);
    }
    await refreshDirectory();
  }

  Future<void> copyItem(String sourcePath, String destinationPath) async {
    await _copyItem(sourcePath, destinationPath);
    await refreshDirectory();
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

  Future<void> _copyItem(String sourcePath, String destinationPath) async {
    if (FileSystemEntity.typeSync(sourcePath) ==
        FileSystemEntityType.directory) {
      final sourceDir = Directory(sourcePath);
      final destinationDir = Directory(destinationPath);
      await _copyDirectory(sourceDir, destinationDir);
    } else {
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);
    }
  }

  Future<void> _moveItem(String sourcePath, String destinationPath) async {
    final source =
        FileSystemEntity.typeSync(sourcePath) == FileSystemEntityType.directory
            ? Directory(sourcePath)
            : File(sourcePath);

    try {
      await source.rename(destinationPath);
    } catch (e) {
      // If rename fails (e.g., across devices), fallback to copy and delete
      await _copyItem(sourcePath, destinationPath);
      await source.delete(recursive: true);
    }
  }

  String _generateUniquePathIfNeeded(String destinationPath, String itemName) {
    String newPath = path.join(destinationPath, itemName);

    if (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
      String baseName = path.basenameWithoutExtension(itemName);
      String extension = path.extension(itemName);
      int copyNumber = 1;

      do {
        String newName = '$baseName - Copy';
        if (copyNumber > 1) {
          newName += ' ($copyNumber)';
        }
        newName += extension;
        newPath = path.join(destinationPath, newName);
        copyNumber++;
      } while (
          FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound);
    }

    return newPath;
  }

  Future<void> refreshDirectory() async {
    if (_currentDirectory != null) {
      _rootItems = await _getDirectoryContents(_currentDirectory!, 0, null);
      _sortFileTree(_rootItems);
      notifyListeners();
    }
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

  void setCopiedItems(List<FileTreeItem> items) {
    _copiedItems = items;
    _cutItems.clear();
    notifyListeners();
  }

  // Copy and paste operations
  void setCutItems(List<FileTreeItem> items) {
    _cutItems = items;
    _copiedItems.clear();
    notifyListeners();
  }

  // Navigation methods
  void setDirectory(Directory directory) {
    _currentDirectory = directory;
    _refreshFileTree();
  }

  // UI helper methods
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Selection methods
  void setSelectedItem(FileTreeItem? item) {
    _selectedItem = item;
    if (!_isMultiSelectMode) {
      _selectedItems.clear();
      if (item != null) {
        _selectedItems.add(item);
      }
    }
    notifyListeners();
  }

  bool isItemSelected(FileTreeItem item) {
    return _selectedItems.contains(item);
  }

  void toggleItemSelection(FileTreeItem item) {
    if (_selectedItems.contains(item)) {
      _selectedItems.remove(item);
    } else {
      _selectedItems.add(item);
    }
    notifyListeners();
  }

  // Private helper methods
  Future<List<FileTreeItem>> _getDirectoryContents(
      Directory directory, int level, FileTreeItem? parent) async {
    List<FileTreeItem> items = [];
    try {
      final entities = await directory.list().toList();
      for (var entity in entities) {
        final item = FileTreeItem(entity, level, false, parent);
        items.add(item);
      }
    } catch (e) {
      print('Error reading directory contents: $e');
    }
    return items;
  }

  bool _isPositionInItem(Offset position, FileTreeItem item) {
    if (item.renderBox == null) return false;
    final itemRect =
        item.renderBox!.localToGlobal(Offset.zero) & item.renderBox!.size;
    return itemRect.contains(position);
  }

  Future<void> _refreshFileTree() async {
    if (_currentDirectory != null) {
      _rootItems = await _getDirectoryContents(_currentDirectory!, 0, null);
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
  RenderBox? renderBox;
  final FileTreeItem? parent;

  FileTreeItem(this.entity, this.level, this.isExpanded, this.parent)
      : children = [];

  bool get isDirectory => entity is Directory;
  String get name => path.split('/').last;
  String get path => entity.path;

  void setRenderBox(RenderBox box) {
    renderBox = box;
  }
}
