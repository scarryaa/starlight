import 'dart:io';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/presentation/editor_widget.dart';

class EditorService {
  final GlobalKey<EditorWidgetState> editorKey = GlobalKey<EditorWidgetState>();
  final List<_EditorState> _undoStack = [];
  final List<_EditorState> _redoStack = [];
  _EditorState _currentState = _EditorState('');

  void handleContentChanged(String newContent,
      {int? cursorPosition, int? selectionStart, int? selectionEnd}) {
    if (_currentState.content != newContent) {
      _undoStack.add(_currentState);
      _redoStack.clear();
      _currentState = _EditorState(
          newContent, cursorPosition, selectionStart, selectionEnd);
    }
  }

  void addSearchAllFilesTab() {
    editorKey.currentState?.addSearchAllFilesTab();
  }

  void closeCurrentFile() {
    editorKey.currentState?.closeCurrentFile();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      _redoStack.add(_currentState);
      _currentState = _undoStack.removeLast();
      _updateEditor();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      _undoStack.add(_currentState);
      _currentState = _redoStack.removeLast();
      _updateEditor();
    }
  }

  void _updateEditor() {
    final editorState = editorKey.currentState;
    if (editorState != null) {
      editorState.updateContent(
        _currentState.content.replaceFirst('\n', ''),
        _currentState.cursorPosition,
        _currentState.selectionStart,
        _currentState.selectionEnd,
      );
      editorState.maintainFocus();
    }
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

class _EditorState {
  final String content;
  final int? cursorPosition;
  final int? selectionStart;
  final int? selectionEnd;

  _EditorState(this.content,
      [this.cursorPosition, this.selectionStart, this.selectionEnd]);
}
