import 'dart:math';

import 'package:starlight/features/editor/domain/models/text_editing_core.dart';

class TextEditingService {
  final TextEditingCore editingCore;

  TextEditingService(this.editingCore);

  void insertText(String text) {
    editingCore.insertText(text);
  }

  void deleteSelection() {
    editingCore.deleteSelection();
  }

  void handleBackspace() {
    editingCore.handleBackspace();
  }

  void handleDelete() {
    editingCore.handleDelete();
  }

  void moveCursor(int horizontalOffset, int verticalOffset) {
    editingCore.moveCursor(horizontalOffset, verticalOffset);
  }

  void setSelection(int start, int end) {
    editingCore.setSelection(start, end);
  }

  void clearSelection() {
    editingCore.clearSelection();
  }

  String getSelectedText() {
    return editingCore.getSelectedText();
  }

  bool hasSelection() {
    return editingCore.hasSelection();
  }

  int getPositionAtColumn(int line, int column) {
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return min(lineStart + column, lineEnd);
  }
}
