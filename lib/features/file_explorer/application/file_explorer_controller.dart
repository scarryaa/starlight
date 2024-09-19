import 'dart:io';
import 'package:flutter/material.dart';
// ignore: no_leading_underscores_for_library_prefixes
import 'package:path/path.dart' as _path;
import 'package:path_provider/path_provider.dart';
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
  Directory? _tempDirectory;

  // Getters
  Directory? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  bool get isMultiSelectMode => _isMultiSelectMode;
  List<FileTreeItem> get rootItems => _rootItems;
  FileTreeItem? get selectedItem => _selectedItem;
  List<FileTreeItem> get selectedItems => _selectedItems.toList();

  // Initialization
  Future<void> initialize() async {
    await initTempDirectory();
  }

  Future<void> initTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    _tempDirectory = Directory(_path.join(tempDir.path, 'file_explorer_temp'));
    if (!await _tempDirectory!.exists()) {
      await _tempDirectory!.create(recursive: true);
    }
  }

  // File operations
  Future<void> createFile(String parentPath, String fileName) async {
    final newFile = File(_path.join(parentPath, fileName));
    await newFile.create();
    await refreshDirectory();
  }

  Future<void> createFolder(String parentPath, String folderName) async {
    final newFolder = Directory(_path.join(parentPath, folderName));
    await newFolder.create();
    await refreshDirectory();
  }

  Future<String> moveToTemp(String sourcePath) async {
    try {
      if (_tempDirectory == null) await initTempDirectory();
      final tempPath =
          _path.join(_tempDirectory!.path, _path.basename(sourcePath));

      if (await FileSystemEntity.type(sourcePath) ==
          FileSystemEntityType.notFound) {
        print('Source file or directory not found: $sourcePath');
        throw FileSystemException('File or directory not found', sourcePath);
      }

      final sourceEntity = await FileSystemEntity.type(sourcePath) ==
              FileSystemEntityType.directory
          ? Directory(sourcePath)
          : File(sourcePath);

      if (sourceEntity is File) {
        await sourceEntity.copy(tempPath);
        await sourceEntity.delete();
      } else if (sourceEntity is Directory) {
        await _copyDirectory(sourceEntity, Directory(tempPath));
        await sourceEntity.delete(recursive: true);
      }

      return tempPath;
    } catch (e) {
      print('Error in moveToTemp: $e');
      rethrow;
    }
  }

  Future<void> clearTempDirectory() async {
    if (_tempDirectory != null && await _tempDirectory!.exists()) {
      await _tempDirectory!.delete(recursive: true);
      await _tempDirectory!.create();
    }
  }

  Future<List<FileOperation>> pasteItems(String destinationPath) async {
    final itemsToPaste = _cutItems.isNotEmpty ? _cutItems : _copiedItems;
    final isCutOperation = _cutItems.isNotEmpty;
    List<FileOperation> operations = [];

    for (var item in itemsToPaste) {
      final newPath = isCutOperation
          ? _path.join(destinationPath, item.name)
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

  Future<void> copyItem(String sourcePath, String destinationPath) async {
    await _copyItem(sourcePath, destinationPath);
    await refreshDirectory();
  }

  Future<void> deleteToTemp(String sourcePath) async {
    try {
      if (_tempDirectory == null) await initTempDirectory();
      final tempPath =
          _path.join(_tempDirectory!.path, _path.basename(sourcePath));

      final sourceEntity = await FileSystemEntity.type(sourcePath) ==
              FileSystemEntityType.directory
          ? Directory(sourcePath)
          : File(sourcePath);

      if (sourceEntity is File) {
        await _moveFileToTemp(sourceEntity, tempPath);
      } else if (sourceEntity is Directory) {
        await _moveDirectoryToTemp(sourceEntity, tempPath);
      } else {
        throw FileSystemException('Entity not found', sourcePath);
      }

      await refreshDirectory();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _moveFileToTemp(File file, String tempPath) async {
    await file.copy(tempPath);
    await file.delete();
  }

  Future<void> _moveDirectoryToTemp(Directory dir, String tempPath) async {
    await _copyDirectory(dir, Directory(tempPath));
    await dir.delete(recursive: true);
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
    final newPath = _path.join(oldFile.parent.path, newName);
    await oldFile.rename(newPath);
    await refreshDirectory();
  }

  // Selection methods
  void selectItem(FileTreeItem item) {
    if (!_isMultiSelectMode) {
      enterMultiSelectMode();
    }
    if (!_selectedItems.contains(item)) {
      _selectedItems.add(item);
      _selectedItem = item;
      notifyListeners();
    }
  }

  void deselectItem(FileTreeItem item) {
    if (_selectedItems.remove(item)) {
      if (_selectedItems.isEmpty) {
        exitMultiSelectMode();
      } else if (_selectedItem == item) {
        _selectedItem = _selectedItems.last;
      }
      notifyListeners();
    }
  }

  void enterMultiSelectMode() {
    if (!_isMultiSelectMode) {
      _isMultiSelectMode = true;
      notifyListeners();
    }
  }

  void exitMultiSelectMode() {
    if (_isMultiSelectMode) {
      _isMultiSelectMode = false;
      _selectedItems.clear();
      notifyListeners();
    }
  }

  void setSelectedItem(FileTreeItem? item) {
    selectItem(item!);
  }

  void clearSelectedItems() {
    _selectedItems.clear();
    notifyListeners();
  }

  bool isItemSelected(FileTreeItem item) {
    return _selectedItems.contains(item);
  }

  void toggleItemSelection(FileTreeItem item) {
    if (_selectedItems.contains(item)) {
      deselectItem(item);
    } else {
      selectItem(item);
    }
  }

  void clearSelection() {
    _selectedItems.clear();
  }

  // Copy and cut operations
  void setCopiedItems(List<FileTreeItem> items) {
    _copiedItems = items;
    _cutItems.clear();
    notifyListeners();
  }

  void setCutItems(List<FileTreeItem> items) {
    _cutItems = items;
    _copiedItems.clear();
    notifyListeners();
  }

  // Navigation methods
  void setDirectory(Directory directory) async {
    _currentDirectory = directory;
    await refreshDirectory();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Helper methods
  String getTempPath(String originalPath) {
    return _path.join(_tempDirectory!.path, _path.basename(originalPath));
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

  Future<bool> itemExists(String path) async {
    return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
  }

  Future<void> moveItem(String sourcePath, String destinationPath) async {
    if (!await itemExists(sourcePath)) {
      print('Source item does not exist: $sourcePath');
      return;
    }

    final source = await FileSystemEntity.isDirectory(sourcePath)
        ? Directory(sourcePath)
        : File(sourcePath);

    try {
      await source.rename(destinationPath);
    } catch (e) {
      print('Error moving item: $e');
      // If rename fails (e.g., across devices), fallback to copy and delete
      await _copyItem(sourcePath, destinationPath);
      await source.delete(recursive: true);
    }
  }

  Future<void> restoreFromTemp(String originalPath) async {
    if (_tempDirectory == null) {
      await initTempDirectory();
    }

    final tempPath =
        _path.join(_tempDirectory!.path, _path.basename(originalPath));

    if (!await itemExists(tempPath)) {
      print('Temp file does not exist: $tempPath');
      return;
    }

    final fileOrDir = await FileSystemEntity.isDirectory(tempPath)
        ? Directory(tempPath)
        : File(tempPath);

    try {
      await fileOrDir.rename(originalPath);
    } catch (e) {
      print('Error restoring from temp: $e');
      // If rename fails (e.g., across devices), fallback to copy and delete
      await _copyItem(tempPath, originalPath);
      await fileOrDir.delete(recursive: true);
    }
  }

  // Private helper methods
  Future<void> _copyItem(String sourcePath, String destinationPath) async {
    if (FileSystemEntity.typeSync(sourcePath) ==
        FileSystemEntityType.directory) {
      await _copyDirectory(Directory(sourcePath), Directory(destinationPath));
    } else {
      await File(sourcePath).copy(destinationPath);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(
            _path.join(destination.path, _path.basename(entity.path)));
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity
            .copy(_path.join(destination.path, _path.basename(entity.path)));
      }
    }
  }

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

  String _generateUniquePathIfNeeded(String destinationPath, String itemName) {
    String newPath = _path.join(destinationPath, itemName);

    if (FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound) {
      String baseName = _path.basenameWithoutExtension(itemName);
      String extension = _path.extension(itemName);
      int copyNumber = 1;

      do {
        String newName = '$baseName - Copy';
        if (copyNumber > 1) {
          newName += ' ($copyNumber)';
        }
        newName += extension;
        newPath = _path.join(destinationPath, newName);
        copyNumber++;
      } while (
          FileSystemEntity.typeSync(newPath) != FileSystemEntityType.notFound);
    }

    return newPath;
  }

  void _sortFileTree(List<FileTreeItem> items) {
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
  }

  @override
  Future<void> dispose() async {
    await clearTempDirectory();
    super.dispose();
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
  String get name => _path.basename(path);
  String get path => entity.path;

  void setRenderBox(RenderBox box) {
    renderBox = box;
  }
}
