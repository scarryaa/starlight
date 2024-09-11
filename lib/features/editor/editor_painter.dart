import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditorPainter extends CustomPainter {
  static const double lineHeight = 24.0;
  static const double fontSize = 14.0;
  static const int lineBuffer = 5;

  final TextEditingCore editingCore;
  final int firstVisibleLine;
  final int visibleLineCount;
  final double horizontalOffset;
  final int version;
  final double viewportWidth;
  final double lineNumberWidth;

  late double charWidth;
  final TextStyle textStyle = const TextStyle(
    fontSize: fontSize,
    color: Colors.black,
    fontFamily: 'Courier',
  );

  CodeEditorPainter({
    required this.editingCore,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.horizontalOffset,
    required this.lineNumberWidth,
    required this.version,
    required this.viewportWidth,
  }) {
    _calculateCharWidth();
  }

  void _calculateCharWidth() {
    final textPainter = TextPainter(
      text: TextSpan(text: 'X', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    charWidth = textPainter.width;
  }

  @override
  @override
  void paint(Canvas canvas, Size size) {
    final lineCount = editingCore.lineCount;
    final visibleEndLine =
        min(firstVisibleLine + visibleLineCount + lineBuffer, lineCount);

    for (int i = firstVisibleLine; i < visibleEndLine; i++) {
      final lineContent = _getLineContent(i);

      // Paint line content
      _paintText(canvas, lineContent, Offset(0, i * lineHeight));

      // Paint selection if needed
      if (_isLineSelected(i)) {
        _paintSelection(canvas, i, lineContent);
      }

      // Paint cursor
      if (_isCursorOnLine(i)) {
        _paintCursor(canvas, i, lineContent);
      }
    }

    // Paint cursor at the end of the document if necessary
    if (editingCore.cursorPosition == editingCore.length) {
      _paintCursorAtEnd(canvas, lineCount - 1);
    }
  }

  String _getLineContent(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= editingCore.lineCount) {
      return '';
    }
    return editingCore.getLineContent(lineIndex);
  }

  void _paintText(Canvas canvas, String text, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    final yOffset = offset.dy + (lineHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(offset.dx, yOffset));
  }

  void _paintSelection(Canvas canvas, int line, String lineContent) {
    if (!editingCore.hasSelection()) return;

    final selectionPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3);
    final selectionStart = _getSelectionStartForLine(line);
    final selectionEnd = _getSelectionEndForLine(line);

    final topY = (line * lineHeight) + (lineHeight - fontSize) / 2;
    final bottomY = topY + fontSize;

    canvas.drawRect(
      Rect.fromLTRB(
        selectionStart * charWidth,
        topY,
        selectionEnd * charWidth,
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
      Offset(cursorOffset, topY),
      Offset(cursorOffset, bottomY),
      Paint()..color = Colors.blue,
    );
  }

  void _paintCursorAtEnd(Canvas canvas, int lastLine) {
    final cursorOffset = _getLineContent(lastLine).length * charWidth;

    final topY = lastLine * lineHeight + (lineHeight - fontSize) / 2;
    final bottomY = topY + fontSize;

    canvas.drawLine(
      Offset(cursorOffset, topY),
      Offset(cursorOffset, bottomY),
      Paint()..color = Colors.blue,
    );
  }

  bool _isLineSelected(int line) {
    if (!editingCore.hasSelection()) return false;
    int selectionStart =
        min(editingCore.selectionStart ?? 0, editingCore.selectionEnd ?? 0);
    int selectionEnd =
        max(editingCore.selectionStart ?? 0, editingCore.selectionEnd ?? 0);
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return (selectionStart < lineEnd && selectionEnd > lineStart);
  }

  int _getSelectionStartForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionStart =
        min(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = editingCore.getLineStartIndex(line);
    return max(0, selectionStart - lineStart);
  }

  int _getSelectionEndForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionEnd =
        max(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return min(lineEnd - lineStart, selectionEnd - lineStart);
  }

  bool _isCursorOnLine(int line) {
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return editingCore.cursorPosition >= lineStart &&
        editingCore.cursorPosition <= lineEnd;
  }

  int _getCursorPositionInLine(int line) {
    int lineStart = editingCore.getLineStartIndex(line);
    return editingCore.cursorPosition - lineStart;
  }

  @override
  bool shouldRepaint(CodeEditorPainter oldDelegate) {
    return editingCore != oldDelegate.editingCore ||
        firstVisibleLine != oldDelegate.firstVisibleLine ||
        visibleLineCount != oldDelegate.visibleLineCount ||
        horizontalOffset != oldDelegate.horizontalOffset ||
        version != oldDelegate.version ||
        viewportWidth != oldDelegate.viewportWidth;
  }
}
