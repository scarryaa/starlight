import 'package:flutter/material.dart';
import 'package:starlight/models/rope.dart';

class TextEditingCore extends ChangeNotifier {
  Rope rope;
  int cursorPosition = 0;
  int? selectionStart;
  int? selectionEnd;
  int _version = 0;

  TextEditingCore(String initialText) : rope = Rope(initialText);

  int get version => _version;
  void incrementVersion() {
    _version++;
    notifyListeners();
  }

  int get lineCount => rope.lineCount;
  int get length => rope.length;

  String getLineContent(int line) {
    int start = rope.findLineStart(line);
    int end = line < rope.lineCount - 1
        ? rope.findLineStart(line + 1) - 1
        : rope.length;
    return rope.slice(start, end);
  }

  void moveCursor(int horizontalMove, int verticalMove) {
    if (rope.length == 0 || rope.lineCount == 0) {
      cursorPosition = 0;
      return;
    }

    int currentLine = rope.findLine(cursorPosition.clamp(0, rope.length - 1));
    if (currentLine < 0) return;

    int lineStart = rope.findLineStart(currentLine);
    int currentColumn = cursorPosition - lineStart;

    // Apply vertical movement
    currentLine = (currentLine + verticalMove).clamp(0, rope.lineCount - 1);

    // Check if the new line is valid before proceeding
    if (currentLine < 0 || currentLine >= rope.lineCount) {
      return; // Exit the method if the new line is invalid
    }

    // Apply horizontal movement
    int newLineStart = rope.findLineStart(currentLine);
    int newLineEnd = currentLine < rope.lineCount - 1
        ? rope.findLineStart(currentLine + 1) - 1
        : rope.length;
    int lineLength = newLineEnd - newLineStart;

    if (verticalMove == 0) {
      currentColumn = (currentColumn + horizontalMove).clamp(0, lineLength);
    } else {
      currentColumn = currentColumn.clamp(0, lineLength);
    }

    cursorPosition = (newLineStart + currentColumn).clamp(0, rope.length);
    incrementVersion();
  }

  void insertText(String text) {
    if (hasSelection()) deleteSelection();
    rope = rope.insert(cursorPosition, text);
    cursorPosition += text.length;
    incrementVersion();
    clearSelection();
  }

  void handleBackspace() {
    if (hasSelection()) {
      deleteSelection();
    } else if (cursorPosition > 1) {
      rope = rope.delete(cursorPosition - 1, cursorPosition);
      cursorPosition--;
      incrementVersion();
    }
    clearSelection();
  }

  void handleDelete() {
    if (hasSelection()) {
      deleteSelection();
    } else if (cursorPosition < rope.length) {
      rope = rope.delete(cursorPosition, cursorPosition + 1);
      incrementVersion();
    }
    clearSelection();
  }

  bool hasSelection() => selectionStart != null && selectionEnd != null;

  String getSelectedText() {
    if (!hasSelection()) return '';
    int start =
        selectionStart! < selectionEnd! ? selectionStart! : selectionEnd!;
    int end = selectionStart! < selectionEnd! ? selectionEnd! : selectionStart!;
    return rope.slice(start, end);
  }

  void deleteSelection() {
    if (!hasSelection()) return;
    int start =
        selectionStart! < selectionEnd! ? selectionStart! : selectionEnd!;
    int end = selectionStart! < selectionEnd! ? selectionEnd! : selectionStart!;
    rope = rope.delete(start, end);
    cursorPosition = start;
    incrementVersion();
    clearSelection();
  }

  int getLineStartIndex(int lineIndex) {
    return rope.findLineStart(lineIndex);
  }

  int getLineEndIndex(int lineIndex) {
    return rope.findLineEnd(lineIndex);
  }

  void clearSelection() {
    selectionStart = selectionEnd = null;
    incrementVersion();
  }

  void setSelection(int start, int end) {
    selectionStart = start;
    selectionEnd = end;
    incrementVersion();
  }

  String getText() {
    return rope.toString();
  }
}
