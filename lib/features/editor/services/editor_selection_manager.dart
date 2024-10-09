import 'dart:math';
import 'package:starlight/features/editor/models/selection_mode.dart';
import 'package:starlight/features/editor/models/rope.dart';

class EditorSelectionManager {
  SelectionMode _selectionMode = SelectionMode.normal;
  int selectionStart = -1;
  int selectionEnd = -1;
  int selectionAnchor = -1;
  int selectionFocus = -1;
  Rope rope;

  EditorSelectionManager(this.rope);

  SelectionMode get selectionMode => _selectionMode;

  void setSelectionMode(SelectionMode mode) {
    _selectionMode = mode;
  }

  void updateRope(Rope r) {
    rope = r;
  }

  void clearSelection() {
    selectionAnchor = -1;
    selectionFocus = -1;
    selectionStart = -1;
    selectionEnd = -1;
  }

  void updateSelection() {
    if (selectionAnchor != -1 && selectionFocus != -1) {
      selectionStart = min(selectionAnchor, selectionFocus);
      selectionEnd = max(selectionAnchor, selectionFocus);
    } else {
      selectionStart = selectionEnd = -1;
    }
  }

  bool hasSelection() {
    return selectionStart != -1 &&
        selectionEnd != -1 &&
        selectionStart != selectionEnd;
  }

  void moveSelectionHorizontally(int target) {
    if (target > 0) {
      selectionEnd = target;
      if (selectionStart == -1) {
        selectionStart = target;
      }
    } else {
      selectionStart = target;
    }
    normalizeSelection();
  }

  void moveSelectionVertically(int target) {
    if (target > 0) {
      selectionEnd = target;
    } else {
      selectionStart = target;
    }
    normalizeSelection();
  }

  void normalizeSelection() {
    if (selectionStart > selectionEnd) {
      int temp = selectionStart;
      selectionStart = selectionEnd;
      selectionEnd = temp;
    }
  }

  void selectWord(int position) {
    selectionAnchor = findWordBoundary(position, true);
    selectionFocus = findWordBoundary(position, false);
    updateSelection();
  }

  void selectLine(int position) {
    int lineNumber = rope.findLineForPosition(position);
    selectionAnchor = rope.findClosestLineStart(lineNumber);
    selectionFocus = lineNumber < rope.lineCount - 1
        ? rope.findClosestLineStart(lineNumber + 1) - 1
        : rope.length;
    updateSelection();
  }

  void updateWordSelection(int position) {
    if (position > selectionAnchor) {
      selectionFocus = findWordBoundary(position, false);
    } else {
      selectionFocus = findWordBoundary(position, true);
    }
    updateSelection();
  }

  void updateLineSelection(int position) {
    int anchorLine = rope.findLineForPosition(selectionAnchor);
    int currentLine = rope.findLineForPosition(position);

    if (currentLine < anchorLine) {
      selectionFocus = rope.findClosestLineStart(currentLine);
    } else {
      selectionFocus = currentLine < rope.lineCount - 1
          ? rope.findClosestLineStart(currentLine + 1) - 1
          : rope.length;
    }
    updateSelection();
  }

  int findWordBoundary(int position, bool isStart) {
    position = position.clamp(0, rope.length);
    if (position == rope.length) return position;

    bool isWordChar(String char) {
      return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
    }

    int lineStart =
        rope.findClosestLineStart(rope.findLineForPosition(position));
    int lineEnd =
        rope.findClosestLineStart(rope.findLineForPosition(position) + 1) - 1;

    if (isStart) {
      while (position > lineStart && !isWordChar(rope.charAt(position - 1))) {
        position--;
      }
      while (position > lineStart && isWordChar(rope.charAt(position - 1))) {
        position--;
      }
    } else {
      while (position < lineEnd && !isWordChar(rope.charAt(position))) {
        position++;
      }
      while (position < lineEnd && isWordChar(rope.charAt(position))) {
        position++;
      }
    }

    return position;
  }

  void handleTapSelection(int tapPosition) {
    switch (_selectionMode) {
      case SelectionMode.normal:
        clearSelection();
        selectionStart = selectionEnd = tapPosition;
        break;
      case SelectionMode.word:
        selectWord(tapPosition);
        break;
      case SelectionMode.line:
        selectLine(tapPosition);
        break;
    }
  }

  void handleDragSelection(int currentPosition) {
    switch (_selectionMode) {
      case SelectionMode.normal:
        selectionFocus = currentPosition;
        break;
      case SelectionMode.word:
        updateWordSelection(currentPosition);
        break;
      case SelectionMode.line:
        updateLineSelection(currentPosition);
        break;
    }
    updateSelection();
  }
}

