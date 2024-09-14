import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:starlight/features/file_explorer/application/file_explorer_controller.dart';

class FileExplorerService {
  final ValueNotifier<String?> selectedDirectory = ValueNotifier<String?>(null);
  late final FileExplorerController _fileExplorerController;

  FileExplorerService() {
    _fileExplorerController = FileExplorerController();
  }

  FileExplorerController get controller => _fileExplorerController;

  void handleDirectorySelected(String? directory) {
    selectedDirectory.value = directory;
    if (directory != null) {
      _fileExplorerController.setDirectory(Directory(directory));
    }
  }

  Future<void> pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      handleDirectorySelected(selectedDirectory);
    }
  }
}
