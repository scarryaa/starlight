import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditorPainter extends CustomPainter {
  static const double lineHeight = 24.0;
  static late double charWidth;
  static const double fontSize = 14.0;
  static const int _lineBuffer = 5;

  final TextEditingCore editingCore;
  final int firstVisibleLine;
  final int visibleLineCount;
  final double horizontalOffset;
  final int version;

  final TextStyle _textStyle = const TextStyle(
      fontSize: fontSize, color: Colors.black, fontFamily: 'Courier');

  CodeEditorPainter({
    required this.editingCore,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.horizontalOffset,
    required this.version,
  }) {
    _calculateCharWidth();
  }

  void _calculateCharWidth() {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: 'X', style: _textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    charWidth = textPainter.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lineCount = editingCore.rope.lineCount;

    for (int i = firstVisibleLine;
        i < min(firstVisibleLine + visibleLineCount + _lineBuffer, lineCount);
        i++) {
      final lineContent = _safeGetLineContent(i);

      // Paint line content
      _paintText(canvas, lineContent, Offset(horizontalOffset, i * lineHeight),
          _textStyle);

      // Paint selection if needed
      if (_isLineSelected(i)) {
        _paintSelection(canvas, i, lineContent);
      }

      // Paint cursor
      if (_isCursorOnLine(i)) {
        _paintCursor(canvas, i, lineContent);
      }
    }
  }

  String _safeGetLineContent(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= editingCore.rope.lineCount) {
      print(
          "Warning: Attempted to access invalid line $lineIndex. Total lines: ${editingCore.rope.lineCount}");
      return '';
    }
    try {
      return editingCore.getLineContent(lineIndex);
    } catch (e) {
      print("Error getting content for line $lineIndex: $e");
      return '';
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style,
      [TextAlign align = TextAlign.left]) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout();

    // Horizontal centering
    final xOffset =
        offset.dx + (charWidth * text.length - textPainter.width) / 2;

    // Vertical centering
    final yOffset = offset.dy + (lineHeight - textPainter.height) / 2;

    textPainter.paint(canvas, Offset(xOffset, yOffset));
  }

  void _paintSelection(Canvas canvas, int line, String lineContent) {
    final selectionPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3);
    final selectionStart = _getSelectionStartForLine(line);
    final selectionEnd = _getSelectionEndForLine(line);

    final topY = (line * lineHeight) + (lineHeight - fontSize) / 2;
    final bottomY = topY + fontSize;

    canvas.drawRect(
      Rect.fromLTRB(
        selectionStart * charWidth - horizontalOffset,
        topY,
        selectionEnd * charWidth - horizontalOffset,
        bottomY,
      ),
      selectionPaint,
    );
  }

  void _paintCursor(Canvas canvas, int line, String lineContent) {
    int cursorPositionInLine = _getCursorPositionInLine(line);
    final cursorOffset = cursorPositionInLine * charWidth;

    final topY = line * lineHeight + (lineHeight - fontSize) / 2;
    final bottomY = topY + fontSize;

    canvas.drawLine(
      Offset(cursorOffset - horizontalOffset, topY),
      Offset(cursorOffset - horizontalOffset, bottomY),
      Paint()..color = Colors.blue,
    );
  }

  bool _isLineSelected(int line) {
    if (!editingCore.hasSelection()) return false;
    int selectionStart =
        min(editingCore.selectionStart ?? 0, editingCore.selectionEnd ?? 0);
    int selectionEnd =
        max(editingCore.selectionStart ?? 0, editingCore.selectionEnd ?? 0);
    int lineStart = _safeGetLineStartIndex(line);
    int lineEnd = _safeGetLineEndIndex(line);
    return (selectionStart < lineEnd && selectionEnd > lineStart);
  }

  int _getSelectionStartForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionStart =
        min(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = _safeGetLineStartIndex(line);
    return max(0, selectionStart - lineStart);
  }

  int _getSelectionEndForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionEnd =
        max(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = _safeGetLineStartIndex(line);
    int lineEnd = _safeGetLineEndIndex(line);
    return min(lineEnd - lineStart, selectionEnd - lineStart);
  }

  bool _isCursorOnLine(int line) {
    int lineStart = _safeGetLineStartIndex(line);
    int lineEnd = _safeGetLineEndIndex(line);
    return editingCore.cursorPosition >= lineStart &&
        editingCore.cursorPosition <= lineEnd;
  }

  int _getCursorPositionInLine(int line) {
    int lineStart = _safeGetLineStartIndex(line);
    return editingCore.cursorPosition - lineStart;
  }

  int _safeGetLineStartIndex(int line) {
    if (line < 0 || line >= editingCore.rope.lineCount) {
      return 0;
    }
    return editingCore.getLineStartIndex(line);
  }

  int _safeGetLineEndIndex(int line) {
    if (line < 0 || line >= editingCore.rope.lineCount) {
      return editingCore.rope.length;
    }
    return editingCore.getLineEndIndex(line);
  }

  @override
  bool shouldRepaint(CodeEditorPainter oldDelegate) {
    return editingCore != oldDelegate.editingCore ||
        firstVisibleLine != oldDelegate.firstVisibleLine ||
        visibleLineCount != oldDelegate.visibleLineCount ||
        horizontalOffset != oldDelegate.horizontalOffset ||
        version != oldDelegate.version;
  }
}
