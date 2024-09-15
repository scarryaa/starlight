import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';

class EditorService {
  final GlobalKey<EditorWidgetState> editorKey = GlobalKey<EditorWidgetState>();

  void addSearchAllFilesTab() {
    editorKey.currentState?.addSearchAllFilesTab();
  }

  void closeCurrentFile() {
    editorKey.currentState?.closeCurrentFile();
  }

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

  void redo() {
    editorKey.currentState?.redo();
  }

  void resetZoom() {
    editorKey.currentState?.resetZoom();
  }

  void showFindDialog() {
    editorKey.currentState?.showFindDialog();
  }

  void showReplaceDialog() {
    editorKey.currentState?.showReplaceDialog();
  }

  void undo() {
    editorKey.currentState?.undo();
  }

  void zoomIn() {
    editorKey.currentState?.zoomIn();
  }

  void zoomOut() {
    editorKey.currentState?.zoomOut();
  }
}
