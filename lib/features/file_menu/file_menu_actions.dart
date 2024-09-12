import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FileMenuActions {
  late VoidCallback newFile;
  late Function(File) openFile;
  late VoidCallback save;
  late VoidCallback saveAs;
  late Function(BuildContext) exit;

  FileMenuActions({
    required this.newFile,
    required this.openFile,
    required this.save,
    required this.saveAs,
    required this.exit,
  });

  Future<void> openFileDialog() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      File file = File(result.files.single.path!);
      openFile(file);
    }
  }
}
