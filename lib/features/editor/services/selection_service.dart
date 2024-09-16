import 'dart:math';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/enums/selection_mode.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';

typedef PositionFromOffsetCallback = int Function(Offset offset);
typedef AutoScrollCallback = void Function(Offset position, Size size);

class CodeEditorSelectionService {
  final SelectionMode _selectionMode = SelectionMode.character;
  int? _selectionAnchor;
  late TextEditingCore editingCore;
  PositionFromOffsetCallback getPositionFromOffset;
  AutoScrollCallback autoScrollOnDrag;

  CodeEditorSelectionService({
    required this.editingCore,
    required this.getPositionFromOffset,
    required this.autoScrollOnDrag,
  });

  void selectLineAtPosition(int position) {
    int line = editingCore.rope.findLine(position);
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    editingCore.setSelection(lineStart, lineEnd);
    editingCore.cursorPosition =
        lineEnd; // Place cursor at the end of selection
  }

  void selectWordAtPosition(int position) {
    String text = editingCore.getText();
    if (text.isEmpty) return;

    // Find the start and end of the current line
    int lineStart = position;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = position;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    // Check if the click is beyond the last non-whitespace character
    int lastNonWhitespace = lineEnd - 1;
    while (lastNonWhitespace > lineStart &&
        text[lastNonWhitespace].trim().isEmpty) {
      lastNonWhitespace--;
    }

    if (position > lastNonWhitespace) {
      // Click is beyond the last word, so select the last word or special characters
      int wordEnd = lastNonWhitespace + 1;
      int wordStart = wordEnd;

      // Check for compound operators or special character sequences at the end
      String endSequence = text.substring(max(lineStart, wordEnd - 3), wordEnd);
      if (isCompoundOperator(endSequence)) {
        wordStart = wordEnd - endSequence.length;
      } else {
        // Select the last word or symbol group
        wordStart = findWordOrSymbolGroupStart(text, wordEnd - 1, lineStart);
      }
      editingCore.setSelection(wordStart, wordEnd);
    } else {
      // Normal word, symbol, or whitespace selection
      int start = position;
      int end = position;

      if (text[position].trim().isEmpty) {
        // Select contiguous whitespace within the same line
        while (start > lineStart && text[start - 1].trim().isEmpty) {
          start--;
        }
        while (end < lineEnd && text[end].trim().isEmpty) {
          end++;
        }
      } else {
        // Word or symbol group selection
        start = findWordOrSymbolGroupStart(text, position, lineStart);
        end = findWordOrSymbolGroupEnd(text, position, lineEnd);
      }

      editingCore.setSelection(start, end);
      editingCore.cursorPosition = end; // Place cursor at the end of selection
    }
  }

  bool isCompoundOperator(String sequence) {
    final compoundOperators = [
      '++;',
      '--;',
      '+=',
      '-=',
      '*=',
      '/=',
      '%=',
      '&=',
      '|=',
      '^=',
      '>>=',
      '<<='
    ];
    return compoundOperators.any((op) => sequence.endsWith(op));
  }

  void extendSelectionByLineFromAnchor(int anchor, int extent) {
    int anchorLine = editingCore.rope.findLine(anchor);
    int extentLine = editingCore.rope.findLine(extent);

    int newStart = editingCore.getLineStartIndex(min(anchorLine, extentLine));
    int newEnd = editingCore.getLineEndIndex(max(anchorLine, extentLine));

    if (extent >= anchor) {
      // Dragging forward
      editingCore.setSelection(anchor, newEnd);
    } else {
      // Dragging backward
      editingCore.setSelection(newStart, anchor);
    }
  }

  void extendSelectionByWordFromAnchor(int anchor, int extent) {
    int newStart, newEnd;

    if (extent >= anchor) {
      // Dragging forward
      selectWordAtPosition(extent);
      newStart = anchor;
      newEnd = editingCore.selectionEnd!;
    } else {
      // Dragging backward
      selectWordAtPosition(extent);
      newStart = editingCore.selectionStart!;
      newEnd = anchor;
    }

    editingCore.setSelection(newStart, newEnd);
  }

  int findWordOrSymbolGroupEnd(String text, int position, int lineEnd) {
    // ignore: no_leading_underscores_for_local_identifiers
    bool _isSymbol = isSymbol(text[position]);
    int end = position;

    while (end < lineEnd) {
      if (_isSymbol) {
        if (!(isSymbol(text[end]))) break;
      } else {
        if (isWordBoundary(text[end])) break;
      }
      end++;
    }

    return end;
  }

  int findWordOrSymbolGroupStart(String text, int position, int lineStart) {
    // ignore: no_leading_underscores_for_local_identifiers
    bool _isSymbol = isSymbol(text[position]);
    int start = position;

    while (start > lineStart) {
      if (_isSymbol) {
        if (!isSymbol(text[start - 1])) break;
      } else {
        if (isWordBoundary(text[start - 1])) break;
      }
      start--;
    }

    return start;
  }

  bool isWordBoundary(String character) {
    return character.trim().isEmpty ||
        '.,;:!?()[]{}+-*/%&|^<>=!~'.contains(character);
  }

  bool isSymbol(String char) {
    return char.trim().isNotEmpty && isWordBoundary(char);
  }

  void updateSelection(DragStartDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    _selectionAnchor = position;
    if (_selectionMode == SelectionMode.word) {
      selectWordAtPosition(position);
      _selectionAnchor = editingCore.selectionStart;
    } else if (_selectionMode == SelectionMode.line) {
      selectLineAtPosition(position);
      _selectionAnchor = editingCore.selectionStart;
    } else {
      editingCore.setSelection(position, position);
    }
  }

  void updateSelectionOnDrag(DragUpdateDetails details, Size size) {
    final position = getPositionFromOffset(details.localPosition);
    if (_selectionMode == SelectionMode.word) {
      extendSelectionByWordFromAnchor(_selectionAnchor!, position);
    } else if (_selectionMode == SelectionMode.line) {
      extendSelectionByLineFromAnchor(_selectionAnchor!, position);
    } else {
      editingCore.setSelection(_selectionAnchor!, position);
    }

    autoScrollOnDrag(details.localPosition, size);
  }
}
