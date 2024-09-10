import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditorPainter extends CustomPainter {
  static const double lineHeight = 24.0;
  static late double charWidth;
  static const double lineNumberWidth = 50.0;
  static double fontSize = 14.0;

  final TextEditingCore editingCore;
  final int firstVisibleLine;
  final int visibleLineCount;
  final double horizontalOffset;
  final int version;

  final TextStyle _lineNumberStyle =
      TextStyle(fontSize: fontSize, color: Colors.grey[600]);
  final TextStyle _textStyle =
      TextStyle(fontSize: fontSize, color: Colors.black, fontFamily: 'Courier');

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
    List<String> lines = editingCore.getText().split('\n');

    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount;
        i++) {
      if (i >= lines.length) break;

      final lineContent = lines[i];
      final lineNumber = '${i + 1}'.padLeft(lines.length.toString().length);

      // Paint line number
      _paintText(
          canvas,
          lineNumber,
          Offset(lineNumberWidth - lineNumberWidth / 2, i * lineHeight),
          _lineNumberStyle,
          TextAlign.right);

      // Paint line content
      _paintText(
          canvas,
          lineContent,
          Offset(lineNumberWidth - horizontalOffset, i * lineHeight),
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

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style,
      [TextAlign align = TextAlign.left]) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  void _paintSelection(Canvas canvas, int line, String lineContent) {
    final selectionPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3);
    final selectionStart = _getSelectionStartForLine(line);
    final selectionEnd = _getSelectionEndForLine(line);

    final topY = (line) * lineHeight;
    final bottomY = topY + lineHeight;

    canvas.drawRect(
      Rect.fromLTRB(
        lineNumberWidth + selectionStart * charWidth - horizontalOffset,
        topY,
        lineNumberWidth + selectionEnd * charWidth - horizontalOffset,
        bottomY,
      ),
      selectionPaint,
    );
  }

  void _paintCursor(Canvas canvas, int line, String lineContent) {
    int cursorPositionInLine = _getCursorPositionInLine(line);
    final cursorOffset = cursorPositionInLine * charWidth;
    canvas.drawLine(
      Offset(lineNumberWidth + cursorOffset - horizontalOffset,
          (line) * lineHeight),
      Offset(lineNumberWidth + cursorOffset - horizontalOffset,
          (line + 1) * lineHeight),
      Paint()..color = Colors.blue,
    );
  }

  bool _isLineSelected(int line) {
    if (!editingCore.hasSelection()) return false;
    int selectionStart = editingCore.selectionStart ?? 0;
    int selectionEnd = editingCore.selectionEnd ?? 0;
    int lineStart = _getLineStartIndex(line);
    int lineEnd = _getLineEndIndex(line);
    return (selectionStart < lineEnd && selectionEnd > lineStart);
  }

  int _getSelectionStartForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionStart =
        min(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = _getLineStartIndex(line);
    return max(0, selectionStart - lineStart);
  }

  int _getSelectionEndForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionEnd =
        max(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = _getLineStartIndex(line);
    int lineEnd = _getLineEndIndex(line);
    return min(lineEnd - lineStart, selectionEnd - lineStart);
  }

  bool _isCursorOnLine(int line) {
    int lineStart = _getLineStartIndex(line);
    int lineEnd = _getLineEndIndex(line);
    return editingCore.cursorPosition >= lineStart &&
        editingCore.cursorPosition <= lineEnd;
  }

  int _getCursorPositionInLine(int line) {
    int lineStart = _getLineStartIndex(line);
    return editingCore.cursorPosition - lineStart;
  }

  int _getLineStartIndex(int line) {
    return editingCore.getLineStartIndex(line);
  }

  int _getLineEndIndex(int line) {
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
