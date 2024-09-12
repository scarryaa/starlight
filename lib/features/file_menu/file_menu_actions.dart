import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';

class FileMenuActions {
  final Function(String, String) addNewTab;
  final Function(File) openFile;
  final Function() saveCurrentFile;
  final Function() saveFileAs;

  FileMenuActions({
    required this.addNewTab,
    required this.openFile,
    required this.saveCurrentFile,
    required this.saveFileAs,
  });

  void newFile() {
    addNewTab('Untitled', '');
  }

  void openFileDialog() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      openFile(file);
    }
  }

  void save() {
    saveCurrentFile();
  }

  void saveAs() {
    saveFileAs();
  }

  void exit(BuildContext context) {
    windowManager.close();
  }
}
