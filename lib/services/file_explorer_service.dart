import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/features/file_explorer/domain/models/file_tree_item.dart';
import 'package:starlight/services/settings_service.dart';

class FileExplorerService extends ChangeNotifier {
  final ValueNotifier<String?> selectedDirectory = ValueNotifier<String?>(null);
  final ValueNotifier<FileTreeItem?> currentFileNotifier = ValueNotifier(null);
  late final FileExplorerController _fileExplorerController;
  SettingsService _settingsService;

  FileExplorerService(this._settingsService) {
    _fileExplorerController = FileExplorerController();
    _loadLastDirectory();
  }

  FileExplorerController get controller => _fileExplorerController;

  void handleDirectorySelected(String? directory) {
    selectedDirectory.value = directory;
    if (directory != null) {
      _fileExplorerController.setDirectory(Directory(directory));
      _settingsService.setLastDirectory(directory);
    }
  }

  void updateSettings(SettingsService newSettings) {
    _settingsService = newSettings;
    notifyListeners();
  }

  Future<void> pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      handleDirectorySelected(selectedDirectory);
    }
  }

  void _loadLastDirectory() {
    String? lastDirectory = _settingsService.getLastDirectory();
    if (lastDirectory != null) {
      handleDirectorySelected(lastDirectory);
    }
  }

  Future<void> revealAndExpandToFile(String filePath) async {
    if (selectedDirectory.value == null ||
        !filePath.startsWith(selectedDirectory.value!)) {
      print('File is not within the current directory structure');
      return;
    }
    await _expandToFile(filePath);
    _highlightFile(filePath);
  }

  Future<void> _expandToFile(String filePath) async {
    List<String> pathParts =
        path.split(path.relative(filePath, from: selectedDirectory.value!));
    String currentPath = selectedDirectory.value!;
    for (int i = 0; i < pathParts.length - 1; i++) {
      currentPath = path.join(currentPath, pathParts[i]);
      await expandDirectory(currentPath);
    }
  }

  Future<void> expandDirectory(String dirPath) async {
    FileTreeItem? item = _findFileTreeItem(dirPath);
    if (item != null && item.isDirectory && !item.isExpanded) {
      await _fileExplorerController.toggleDirectoryExpansion(item);
      // Wait for the UI to update
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _highlightFile(String filePath) {
    FileTreeItem? fileItem = _findFileTreeItem(filePath);
    if (fileItem != null) {
      _fileExplorerController.clearSelectedItems();
      _fileExplorerController.setSelectedItem(fileItem);
      setCurrentFile(fileItem);
    } else {
      print('File not found in the current directory structure: $filePath');
    }
  }

  FileTreeItem? _findFileTreeItem(String itemPath) {
    return _searchFileTreeItem(_fileExplorerController.rootItems, itemPath);
  }

  FileTreeItem? _searchFileTreeItem(List<FileTreeItem> items, String itemPath) {
    for (var item in items) {
      if (item.path == itemPath) {
        return item;
      }
      if (item.isDirectory && item.isExpanded) {
        final result = _searchFileTreeItem(item.children, itemPath);
        if (result != null) {
          return result;
        }
      }
    }
    return null;
  }

  void setCurrentFile(FileTreeItem? file) {
    currentFileNotifier.value = file;
    notifyListeners();
  }
}
