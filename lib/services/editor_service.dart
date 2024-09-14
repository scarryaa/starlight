import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';

class EditorService {
  final GlobalKey<EditorWidgetState> editorKey = GlobalKey<EditorWidgetState>();

  void handleNewFile() {
    editorKey.currentState?.addEmptyTab();
  }

  void handleOpenFile(File file) {
    editorKey.currentState?.openFile(file);
  }

  void handleSaveCurrentFile() {
    editorKey.currentState?.saveCurrentFile();
  }

  void handleSaveFileAs() {
    editorKey.currentState?.saveFileAs();
  }
}
