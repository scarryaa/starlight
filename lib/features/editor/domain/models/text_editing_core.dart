import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/models/rope.dart';

class TextEditingCore extends ChangeNotifier {
  Rope rope;
  String originalContent;
  int cursorPosition = 0;
  int? selectionStart;
  int? selectionEnd;
  int _version = 0;
  int _lastModifiedLine = -1;
  bool _isModified = false;

  TextEditingCore(String initialText)
      : originalContent = initialText,
        rope = Rope(initialText.isEmpty ? '\n' : initialText) {
    cursorPosition = rope.length > 0 ? rope.length - 1 : 0;
  }

  bool get isModified => _isModified;

  int get lastModifiedLine => _lastModifiedLine;
  int get length => rope.length;
  int get lineCount => rope.lineCount;
  int get version => _version;

  void checkModificationStatus() {
    bool currentStatus = getText() != originalContent;
    if (_isModified != currentStatus) {
      _isModified = currentStatus;
      notifyListeners();
    }
  }

  void clearSelection() {
    selectionStart = selectionEnd = null;
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
    checkModificationStatus();
    notifyListeners();
  }

  List<int> findAllOccurrences(String searchTerm) {
    List<int> positions = [];
    int position = 0;
    while (true) {
      position = rope.indexOf(searchTerm, position);
      if (position == -1) break;
      positions.add(position);
      position += searchTerm.length;
    }
    return positions;
  }

  String getLineContent(int line) {
    int start = rope.findLineStart(line);
    int end = line < rope.lineCount - 1
        ? rope.findLineStart(line + 1) - 1
        : rope.length;
    return rope.slice(start, end);
  }

  int getLineStartIndex(int lineIndex) {
    if (lineIndex < 0) lineIndex = 0;
    if (lineIndex >= rope.lineCount) lineIndex = rope.lineCount - 1;
    return rope.findLineStart(lineIndex);
  }

  int getLineEndIndex(int lineIndex) {
    if (lineIndex < 0) lineIndex = 0;
    if (lineIndex >= rope.lineCount) lineIndex = rope.lineCount - 1;
    return lineIndex < rope.lineCount - 1
        ? rope.findLineStart(lineIndex + 1) - 1
        : rope.length;
  }

  String getSelectedText() {
    if (!hasSelection()) return '';
    int start =
        selectionStart! < selectionEnd! ? selectionStart! : selectionEnd!;
    int end = selectionStart! < selectionEnd! ? selectionEnd! : selectionStart!;
    return rope.slice(start, end);
  }

  String getText() {
    return rope.toString();
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
    checkModificationStatus();
    notifyListeners();
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
    checkModificationStatus();
    notifyListeners();
  }

  bool hasSelection() => selectionStart != null && selectionEnd != null;

  void incrementVersion() {
    _version++;
    notifyListeners();
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
    checkModificationStatus();
    notifyListeners();
  }

  void markAsModified() {
    _isModified = getText() != originalContent;
    notifyListeners();
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

    currentLine = (currentLine + verticalMove).clamp(0, rope.lineCount - 1);

    if (currentLine < 0 || currentLine >= rope.lineCount) {
      return;
    }

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
  }

  void replaceRange(int start, int end, String replacement) {
    print(
        "replaceRange called with start: $start, end: $end, replacement: '$replacement'");
    print("Current rope content: '${rope.toString()}'");

    if (start < 0 || end < 0 || start > rope.length || end > rope.length) {
      print(
          "Error: Invalid range. start: $start, end: $end, rope length: ${rope.length}");
      return;
    }

    if (start > end) {
      print("Error: Start index ($start) is greater than end index ($end)");
      return;
    }

    try {
      rope = rope.delete(start, end);
      rope = rope.insert(start, replacement);
      cursorPosition = start + replacement.length;
      _updateLastModifiedLine(cursorPosition);
      incrementVersion();
      checkModificationStatus();
      print("replaceRange completed. New rope content: '${rope.toString()}'");
      notifyListeners();
    } catch (e) {
      print("Error in replaceRange: $e");
    }
  }

  void setCursorToStart() {
    cursorPosition = 0;
    clearSelection();
    notifyListeners();
  }

  void setSelection(int start, int end) {
    selectionStart = start;
    selectionEnd = end;
  }

  void setText(String newText) {
    if (rope.length > 0) {
      rope = rope.delete(0, rope.length);
    }

    rope = rope.insert(1, newText);
    cursorPosition = 1;
    _lastModifiedLine = rope.lineCount - 1;
    incrementVersion();
    _isModified = newText != originalContent;
    clearSelection();
    notifyListeners();
  }

  void _updateLastModifiedLine(int position) {
    if (rope.length == 0) {
      _lastModifiedLine = 0;
    } else {
      _lastModifiedLine = rope.findLine(position.clamp(0, rope.length - 1));
    }
  }
}
