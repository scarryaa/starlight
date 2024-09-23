import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';
import 'package:starlight/services/settings_service.dart';

class FileExplorerService {
  final ValueNotifier<String?> selectedDirectory = ValueNotifier<String?>(null);
  late final FileExplorerController _fileExplorerController;
  final SettingsService _settingsService;

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
}
