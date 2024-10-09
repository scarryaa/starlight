import 'dart:math';

import 'package:starlight/features/editor/models/selection_mode.dart';

class EditorSelectionManager {
  SelectionMode selectionMode = SelectionMode.normal;
  int selectionStart = -1;
  int selectionEnd = -1;
  int selectionAnchor = -1;
  int selectionFocus = -1;

  void setSelectionMode(SelectionMode selectionMode) {
    selectionMode = selectionMode;
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
}
