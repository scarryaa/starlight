import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// ignore: no_leading_underscores_for_library_prefixes
import 'package:path/path.dart' as _path;
import 'package:path_provider/path_provider.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/features/file_explorer/infrastructure/file_operation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
  bool _hideSystemFiles = true;
  bool get hideSystemFiles => _hideSystemFiles;
  Timer? _pollingTimer;
  bool _isRefreshCoolingDown = false;
  String? _lastDirectoryHash;

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

  void toggleHideSystemFiles() {
    _hideSystemFiles = !_hideSystemFiles;
    refreshDirectoryImmediately();
  }

  Future<void> refreshDirectoryImmediately() async {
    print('Refreshing directory immediately (bypassing cooldown)');
    await _refreshDirectoryInternal();
  }

  Future<void> _refreshDirectoryInternal() async {
    if (_currentDirectory != null) {
      final selectedPaths = _getSelectedPaths();
      Map<String, bool> expansionState = _getExpansionState(_rootItems);

      _rootItems = await _getDirectoryContents(
          _currentDirectory!, 0, null, expansionState);
      _sortFileTree(_rootItems);

      _restoreSelection(selectedPaths);

      notifyListeners();

      // Update the hash after refresh
      _lastDirectoryHash = _computeDirectoryHash(_currentDirectory!.path);
    }
  }

  void _restoreSelection(List<String> selectedPaths) {
    _selectedItems.clear();
    for (var path in selectedPaths) {
      final item = findItemByPath(path);
      if (item != null) {
        _selectedItems.add(item);
      }
    }
    if (_selectedItems.isNotEmpty) {
      _selectedItem = _selectedItems.last;
    } else {
      _selectedItem = null;
    }
  }

  bool _isSystemFile(String fileName) {
    return fileName.startsWith('.') ||
        ['Thumbs.db', 'desktop.ini', '.DS_Store'].contains(fileName);
  }

  Future<void> initTempDirectory() async {
    final tempDir = await getTemporaryDirectory();
    _tempDirectory = Directory(_path.join(tempDir.path, 'file_explorer_temp'));
    if (!await _tempDirectory!.exists()) {
      await _tempDirectory!.create(recursive: true);
    }
  }

  // File operations
  Future<void> createFile(String? parentPath, String name) async {
    if (parentPath == null) {
      throw Exception('Parent path is null');
    }
    final newFilePath = _path.join(parentPath, name);
    final file = File(newFilePath);
    await file.create();
    await refreshDirectory();
  }

  Future<void> createFolder(String? parentPath, String name) async {
    if (parentPath == null) {
      throw Exception('Parent path is null');
    }
    final newFolderPath = _path.join(parentPath, name);
    final directory = Directory(newFolderPath);
    await directory.create();
    await refreshDirectory();
  }

  Future<void> expandAll() async {
    await _expandRecursively(rootItems);
    notifyListeners();
  }

  void collapseAll() {
    _collapseRecursively(rootItems);
    notifyListeners();
  }

  Future<void> _expandRecursively(List<FileTreeItem> items) async {
    for (var item in items) {
      if (item.isDirectory) {
        item.isExpanded = true;
        item.children = await _getDirectoryContents(
            Directory(item.path), item.level + 1, item);
        await _expandRecursively(item.children);
      }
    }
  }

  void _collapseRecursively(List<FileTreeItem> items) {
    for (var item in items) {
      if (item.isDirectory) {
        item.isExpanded = false;
        _collapseRecursively(item.children);
      }
    }
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

  FileTreeItem? findItemByPath(String path) {
    return _findItemByPathRecursive(rootItems, path);
  }

  FileTreeItem? _findItemByPathRecursive(
      List<FileTreeItem> items, String path) {
    for (var item in items) {
      if (item.path == path) {
        return item;
      }
      if (item.isDirectory) {
        final found = _findItemByPathRecursive(item.children, path);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollDirectory(_currentDirectory!.path);
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _pollDirectory(String path) async {
    if (_isRefreshCoolingDown) {
      print('Polling skipped due to cooldown');
      return;
    }

    final currentHash = _computeDirectoryHash(path);
    if (_lastDirectoryHash != currentHash) {
      print('Directory hash changed, scheduling refresh...');
      _lastDirectoryHash = currentHash;
      await refreshDirectory();
    } else {
      print('No change detected');
    }
  }

  Map<String, bool> _getDirectoryStructure(String path) {
    Map<String, bool> structure = {};
    final dir = Directory(path);
    for (var entity in dir.listSync(recursive: true)) {
      if (!_shouldIgnore(entity.path)) {
        structure[entity.path] = entity is Directory;
      }
    }
    return structure;
  }

  bool _shouldIgnore(String path) {
    return path.contains('.git') ||
        path.contains('node_modules') ||
        path.contains('.plugin_symlinks') ||
        path.contains('.idea') ||
        path.contains('.DS_Store');
  }

  String _computeDirectoryHash(String dirPath) {
    final List<String> fileList = [];
    final dir = Directory(dirPath);
    for (var entity in dir.listSync(recursive: true, followLinks: false)) {
      if (!_shouldIgnore(entity.path) &&
          (!_hideSystemFiles || !_isSystemFile(_path.basename(entity.path)))) {
        fileList.add(
            '${entity.path}|${entity is Directory}|${entity.statSync().modified.millisecondsSinceEpoch}');
      }
    }
    fileList.sort();
    final String concatenatedPaths = fileList.join(',');
    return sha256.convert(utf8.encode(concatenatedPaths)).toString();
  }

  Map<String, bool> _getExistingStructure(List<FileTreeItem> items) {
    Map<String, bool> structure = {};
    for (var item in items) {
      structure[item.path] = item.isDirectory;
      if (item.isDirectory) {
        structure.addAll(_getExistingStructure(item.children));
      }
    }
    return structure;
  }

  bool _compareStructures(
      Map<String, bool> current, Map<String, bool> existing) {
    bool isEqual = true;
    Set<String> allKeys = {...current.keys, ...existing.keys};

    for (var key in allKeys) {
      if (current[key] != existing[key]) {
        print('Difference found: $key');
        print('  Current: ${current[key]}');
        print('  Existing: ${existing[key]}');
        isEqual = false;
      }
    }

    print('Structures equal: $isEqual');
    return isEqual;
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

  Future<void> copyItem(String sourcePath, String destinationPath) async {
    await _copyItem(sourcePath, destinationPath);
    await refreshDirectory();
  }

  Future<void> refreshDirectory() async {
    if (_isRefreshCoolingDown) {
      print('Refresh on cooldown, skipping');
      return;
    }

    await _refreshDirectoryInternal();

    // Set cooldown
    _isRefreshCoolingDown = true;
    Future.delayed(const Duration(seconds: 5), () {
      _isRefreshCoolingDown = false;
    });
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

  Map<String, bool> _getExpansionState(List<FileTreeItem> items) {
    Map<String, bool> state = {};
    for (var item in items) {
      if (item.isDirectory) {
        state[item.path] = item.isExpanded;
        state.addAll(_getExpansionState(item.children));
      }
    }
    return state;
  }

  void _restoreExpansionState(
      List<FileTreeItem> items, Map<String, bool> state) {
    for (var item in items) {
      if (item.isDirectory && state.containsKey(item.path)) {
        item.isExpanded = state[item.path]!;
        _restoreExpansionState(item.children, state);
      }
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
  Future<void> setDirectory(Directory directory) async {
    if (_currentDirectory?.path == directory.path) {
      print('Already in this directory, skipping setDirectory');
      return;
    }
    _stopPolling();
    _currentDirectory = directory;
    _lastDirectoryHash = null; // Reset the hash when changing directories
    _selectedItems.clear();
    _selectedItem = null;
    await refreshDirectory();
    _startPolling();
  }

  List<String> _getSelectedPaths() {
    return _selectedItems.map((item) => item.path).toList();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _pollingTimer?.cancel();
    await clearTempDirectory();
    super.dispose();
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

  Future<void> toggleDirectoryExpansion(FileTreeItem item) async {
    if (item.isDirectory) {
      item.isExpanded = !item.isExpanded;
      if (item.isExpanded && item.children.isEmpty) {
        final selectedPaths = _getSelectedPaths();
        item.children = await _getDirectoryContents(
            Directory(item.path), item.level + 1, item);
        _restoreSelection(selectedPaths);
      }
      notifyListeners();
    }
  }

  Future<List<FileTreeItem>> _getDirectoryContents(
      Directory directory, int level, FileTreeItem? parent,
      [Map<String, bool>? expansionState]) async {
    List<FileTreeItem> items = [];
    try {
      final entities = await directory.list().toList();
      for (var entity in entities) {
        if (!_hideSystemFiles || !_isSystemFile(_path.basename(entity.path))) {
          final item = FileTreeItem(entity, level, false, parent);
          if (item.isDirectory &&
              expansionState != null &&
              expansionState[item.path] == true) {
            item.isExpanded = true;
            item.children = await _getDirectoryContents(
                Directory(item.path), level + 1, item, expansionState);
          }
          items.add(item);
        }
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
}
