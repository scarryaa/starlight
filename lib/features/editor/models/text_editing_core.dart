import 'package:flutter/material.dart';
import 'package:starlight/models/rope.dart';

class TextEditingCore extends ChangeNotifier {
  Rope rope;
  int cursorPosition = 0;
  int? selectionStart;
  int? selectionEnd;
  int _version = 0;
  int _lastModifiedLine = -1;

  TextEditingCore(String initialText)
      : rope = Rope(initialText.isEmpty ? '\n' : initialText) {
    cursorPosition = rope.length > 0 ? rope.length - 1 : 0;
  }

  int get version => _version;
  int get lineCount => rope.lineCount;
  int get length => rope.length;
  int get lastModifiedLine => _lastModifiedLine;

  void setCursorToStart() {
    cursorPosition = 0;
    clearSelection();
    notifyListeners();
  }

  void setText(String newText) {
    // Dumb workaround for incorrect formatting if we set the text directly
    if (rope.length > 0) {
      rope = rope.delete(0, rope.length);
    }

    rope = rope.insert(1, newText);

    cursorPosition = 1;

    _lastModifiedLine = rope.lineCount - 1;
    clearSelection();
    incrementVersion();
  }

  void incrementVersion() {
    _version++;
    notifyListeners();
  }

  void _updateLastModifiedLine(int position) {
    if (rope.length == 0) {
      _lastModifiedLine = 0;
    } else {
      _lastModifiedLine = rope.findLine(position.clamp(0, rope.length - 1));
    }
  }

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
    if (rope.length == 0) {
      rope = Rope(text);
      cursorPosition = text.length;
    } else {
      rope = rope.insert(cursorPosition.clamp(0, rope.length), text);
      cursorPosition += text.length;
    }
    _updateLastModifiedLine(cursorPosition);
    incrementVersion();
    clearSelection();
  }

  void handleBackspace() {
    if (hasSelection()) {
      deleteSelection();
    } else if (cursorPosition > 1) {
      _updateLastModifiedLine(cursorPosition - 1);
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
      _updateLastModifiedLine(cursorPosition);
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
    _updateLastModifiedLine(start);
    rope = rope.delete(start, end);
    cursorPosition = start <= 0 ? start + 1 : start;
    incrementVersion();
    clearSelection();
  }

  int getLineStartIndex(int lineIndex) {
    if (lineIndex < 0) lineIndex = 0;
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
