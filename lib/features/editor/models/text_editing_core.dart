import 'package:flutter/material.dart';
import 'package:starlight/models/rope.dart';

class TextEditingCore extends ChangeNotifier {
  Rope rope;
  int cursorLine = 0;
  int cursorColumn = 0;
  int? selectionStartLine;
  int? selectionStartColumn;
  int? selectionEndLine;
  int? selectionEndColumn;
  int _version = 0;

  TextEditingCore(String initialText) : rope = Rope(initialText);

  int get version => _version;

  void incrementVersion() {
    _version++;
    notifyListeners();
  }

  void moveCursor(int horizontalMove, int verticalMove) {
    if (verticalMove != 0) {
      cursorLine =
          (cursorLine + verticalMove).clamp(0, rope.getLineCount() - 1);
    } else if (horizontalMove != 0) {
      if (horizontalMove > 0 &&
          cursorColumn == rope.getLineContent(cursorLine).length) {
        if (cursorLine < rope.getLineCount() - 1) {
          cursorLine++;
          cursorColumn = 0;
        }
      } else if (horizontalMove < 0 && cursorColumn == 0) {
        if (cursorLine > 0) {
          cursorLine--;
          cursorColumn = rope.getLineContent(cursorLine).length;
        }
      } else {
        cursorColumn = (cursorColumn + horizontalMove)
            .clamp(0, rope.getLineContent(cursorLine).length);
      }
    }

    incrementVersion();
    notifyListeners();
  }

  void insertText(String text) {
    if (hasSelection()) deleteSelection();
    int insertIndex = rope.getLineStartFromIndex(cursorLine) + cursorColumn;
    rope.insert(insertIndex, text);
    List<String> lines = text.split('\n');
    if (lines.length > 1) {
      cursorLine += lines.length - 1;
      cursorColumn = lines.last.length;
    } else {
      cursorColumn += text.length;
    }

    incrementVersion();
    clearSelection();
    notifyListeners();
  }

  void handleBackspace() {
    if (hasSelection()) {
      deleteSelection();
    } else if (cursorColumn > 0) {
      final lineStart = rope.getLineStartFromIndex(cursorLine);
      rope.delete(lineStart + cursorColumn - 1, 1);
      cursorColumn--;
    } else if (cursorLine > 0) {
      final previousLineEnd = rope.getLineEndFromIndex(cursorLine - 1);
      final currentLineContent = rope.getLineContent(cursorLine);
      rope.delete(previousLineEnd, 1);
      cursorLine--;
      cursorColumn = rope.getLineContent(cursorLine).length;
      rope.insert(rope.getLineEndFromIndex(cursorLine), currentLineContent);
    }

    incrementVersion();
    clearSelection();
    notifyListeners();
  }

  void handleDelete() {
    if (hasSelection()) {
      deleteSelection();
    } else if (cursorColumn < rope.getLineContent(cursorLine).length) {
      final lineStart = rope.getLineStartFromIndex(cursorLine);
      rope.delete(lineStart + cursorColumn, 1);
    } else if (cursorLine < rope.getLineCount() - 1) {
      final nextLineContent = rope.getLineContent(cursorLine + 1);
      rope.delete(rope.getLineEndFromIndex(cursorLine), 1);
      rope.insert(rope.getLineEndFromIndex(cursorLine), nextLineContent);
    }

    incrementVersion();
    clearSelection();
    notifyListeners();
  }

  bool hasSelection() => selectionStartLine != null && selectionEndLine != null;

  String getSelectedText() {
    if (!hasSelection()) return '';
    int startLine = selectionStartLine! < selectionEndLine!
        ? selectionStartLine!
        : selectionEndLine!;
    int endLine = selectionStartLine! < selectionEndLine!
        ? selectionEndLine!
        : selectionStartLine!;
    int startColumn = startLine == selectionStartLine!
        ? selectionStartColumn!
        : selectionEndColumn!;
    int endColumn = endLine == selectionEndLine!
        ? selectionEndColumn!
        : selectionStartColumn!;

    String selectedText = '';
    for (int i = startLine; i <= endLine; i++) {
      String lineContent = rope.getLineContent(i);
      if (i == startLine && i == endLine) {
        selectedText += lineContent.substring(startColumn, endColumn);
      } else if (i == startLine) {
        selectedText += '${lineContent.substring(startColumn)}\n';
      } else if (i == endLine) {
        selectedText += lineContent.substring(0, endColumn);
      } else {
        selectedText += '$lineContent\n';
      }
    }
    return selectedText;
  }

  void deleteSelection() {
    if (!hasSelection()) return;
    int startLine = selectionStartLine! < selectionEndLine!
        ? selectionStartLine!
        : selectionEndLine!;
    int endLine = selectionStartLine! < selectionEndLine!
        ? selectionEndLine!
        : selectionStartLine!;
    int startColumn = startLine == selectionStartLine!
        ? selectionStartColumn!
        : selectionEndColumn!;
    int endColumn = endLine == selectionEndLine!
        ? selectionEndColumn!
        : selectionStartColumn!;

    int startIndex = rope.getLineStartFromIndex(startLine) + startColumn;
    int endIndex = rope.getLineStartFromIndex(endLine) + endColumn;

    rope.delete(startIndex, endIndex - startIndex);

    incrementVersion();
    cursorLine = startLine;
    cursorColumn = startColumn;
    clearSelection();
    notifyListeners();
  }

  void clearSelection() {
    selectionStartLine =
        selectionStartColumn = selectionEndLine = selectionEndColumn = null;
  }

  void setSelection(
      int startLine, int startColumn, int endLine, int endColumn) {
    selectionStartLine = startLine;
    selectionStartColumn = startColumn;
    selectionEndLine = endLine;
    selectionEndColumn = endColumn;

    incrementVersion();
    notifyListeners();
  }

  String getText() {
    return rope.toString();
  }

  int getLineCount() {
    return rope.getLineCount();
  }

  String getLineContent(int line) {
    return rope.getLineContent(line);
  }
}
