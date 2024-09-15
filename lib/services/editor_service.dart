import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';

class EditorService {
  final GlobalKey<EditorWidgetState> editorKey = GlobalKey<EditorWidgetState>();
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String _currentContent = '';

  void addSearchAllFilesTab() {
    editorKey.currentState?.addSearchAllFilesTab();
  }

  void closeCurrentFile() {
    editorKey.currentState?.closeCurrentFile();
  }

  void handleContentChanged(String newContent) {
    if (_currentContent != newContent) {
      _undoStack.add(_currentContent);
      _redoStack.clear();
      _currentContent = newContent;
    }
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_currentContent);
      _currentContent = _undoStack.removeLast();
      _updateEditor();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(_currentContent);
      _currentContent = _redoStack.removeLast();
      _updateEditor();
    }
  }

  void _updateEditor() {
    editorKey.currentState
        ?.updateContent(_currentContent.replaceFirst('\n', ''));
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

  void resetZoom() {
    editorKey.currentState?.resetZoom();
  }

  void showFindDialog() {
    editorKey.currentState?.showFindDialog();
  }

  void showReplaceDialog() {
    editorKey.currentState?.showReplaceDialog();
  }

  void zoomIn() {
    editorKey.currentState?.zoomIn();
  }

  void zoomOut() {
    editorKey.currentState?.zoomOut();
  }
}
