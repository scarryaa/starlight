import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/models/selection_mode.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';

class EditorMouseHandler {
  final FocusNode focusNode;
  final Rope rope;
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final Function updateCaretPosition;
  final Function(int start, int end) updateSelection;
  final Function updateLineCounts;
  final EditorSelectionManager selectionManager;

  int _clickCount = 0;
  int _lastClickTime = 0;
  bool _isDragging = false;
  int absoluteCaretPosition = 0;
  int _dragStartPosition = -1;
  static const int _doubleClickTime = 300;

  EditorMouseHandler({
    required this.focusNode,
    required this.rope,
    required this.verticalController,
    required this.horizontalController,
    required this.updateCaretPosition,
    required this.updateSelection,
    required this.updateLineCounts,
    required this.selectionManager,
  });

  void handleTap(TapDownDetails details) {
    focusNode.requestFocus();
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    _clickCount =
        (currentTime - _lastClickTime < _doubleClickTime) ? _clickCount + 1 : 1;
    _lastClickTime = currentTime;

    if (_clickCount == 1) {
      handleClick(details);
      selectionManager.setSelectionMode(SelectionMode.normal);
    } else if (_clickCount == 2) {
      handleDoubleClick(details);
      selectionManager.setSelectionMode(SelectionMode.word);
    } else if (_clickCount == 3) {
      handleTripleClick(details);
      selectionManager.setSelectionMode(SelectionMode.line);
      _clickCount = 0; // Reset after triple click
    }
  }

  void handleClick(TapDownDetails details) {
    absoluteCaretPosition = getPositionFromOffset(details.localPosition);
    selectionManager.clearSelection();
    updateCaretPosition(absoluteCaretPosition);
  }

  void handleDoubleClick(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    final boundaries = getWordBoundaries(position);
    selectionManager.selectionAnchor = boundaries[0];
    selectionManager.selectionFocus = boundaries[1];
    updateSelection(boundaries[0], boundaries[1]);
    updateCaretPosition(boundaries[1]);
  }

  void handleTripleClick(TapDownDetails details) {
    final lineNumber = getLineFromOffset(details.localPosition);
    final lineBoundaries = getLineBoundaries(lineNumber);
    selectionManager.selectionAnchor = lineBoundaries[0];
    selectionManager.selectionFocus = lineBoundaries[1];
    updateSelection(lineBoundaries[0], lineBoundaries[1]);
    updateCaretPosition(lineBoundaries[1]);
  }

  void handleDragStart(DragStartDetails details) {
    focusNode.requestFocus();
    _isDragging = true;
    _dragStartPosition = getPositionFromOffset(details.localPosition);
    selectionManager.selectionAnchor = _dragStartPosition;
    selectionManager.selectionFocus = _dragStartPosition;
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      final currentPosition = getPositionFromOffset(details.localPosition);
      selectionManager.selectionFocus = currentPosition;
      updateSelection(selectionManager.selectionAnchor, currentPosition);
      updateCaretPosition(currentPosition);
    }
  }

  void handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    updateCaretPosition(selectionManager.selectionFocus);
  }

  int getPositionFromOffset(Offset offset) {
    // Logic to determine the caret position based on the offset.
  }

  List<int> getWordBoundaries(int position) {
    // Logic to determine the start and end of a word based on the position.
  }

  List<int> getLineBoundaries(int lineNumber) {
    // Logic to determine the start and end of a line based on the line number.
  }

  int getLineFromOffset(Offset offset) {
    // Logic to determine the line number from the vertical offset.
  }
}
