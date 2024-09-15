import 'dart:math';

import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';

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
  final TextStyle textStyle;
  final Color selectionColor;
  final Color cursorColor;
  final List matchPositions;
  final String searchTerm;
  final Color highlightColor;
  final int cursorPosition;
  final int? selectionStart;
  final int? selectionEnd;
  final double zoomLevel;
  late double scaledLineNumberWidth;
  late double textStartX;

  late double charWidth;

  CodeEditorPainter({
    required this.editingCore,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.horizontalOffset,
    required this.lineNumberWidth,
    required this.version,
    required this.viewportWidth,
    required this.textStyle,
    required this.selectionColor,
    required this.cursorColor,
    required this.matchPositions,
    required this.searchTerm,
    required this.highlightColor,
    required this.cursorPosition,
    required this.selectionStart,
    required this.selectionEnd,
    required this.zoomLevel,
  }) {
    _calculateCharWidth();
    scaledLineNumberWidth = lineNumberWidth * zoomLevel;
    textStartX = scaledLineNumberWidth / 8;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lineCount = editingCore.lineCount;
    final visibleEndLine =
        min(firstVisibleLine + visibleLineCount + lineBuffer, lineCount);
    final scaledLineHeight = lineHeight * zoomLevel;

    for (int i = firstVisibleLine; i < visibleEndLine; i++) {
      final lineContent = _getLineContent(i);
      // Paint search highlights
      _paintSearchHighlights(canvas, i, lineContent);
      // Paint selection if needed
      if (_isLineSelected(i)) {
        _paintSelection(canvas, i, lineContent);
      }
      // Paint line content
      _paintText(canvas, lineContent, Offset(textStartX, i * scaledLineHeight));
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

  @override
  bool shouldRepaint(CodeEditorPainter oldDelegate) {
    return editingCore != oldDelegate.editingCore ||
        firstVisibleLine != oldDelegate.firstVisibleLine ||
        visibleLineCount != oldDelegate.visibleLineCount ||
        horizontalOffset != oldDelegate.horizontalOffset ||
        version != oldDelegate.version ||
        viewportWidth != oldDelegate.viewportWidth ||
        matchPositions != oldDelegate.matchPositions ||
        searchTerm != oldDelegate.searchTerm ||
        cursorPosition != oldDelegate.cursorPosition ||
        selectionStart != oldDelegate.selectionStart ||
        selectionEnd != oldDelegate.selectionEnd ||
        zoomLevel != oldDelegate.zoomLevel;
  }

  void _calculateCharWidth() {
    final textPainter = TextPainter(
      text: TextSpan(text: 'X', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    charWidth = textPainter.width * zoomLevel;
  }

  int _getCursorPositionInLine(int line) {
    int lineStart = editingCore.getLineStartIndex(line);
    return editingCore.cursorPosition - lineStart;
  }

  String _getLineContent(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= editingCore.lineCount) {
      return '';
    }
    return editingCore.getLineContent(lineIndex);
  }

  int _getSelectionEndForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionEnd =
        max(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return min(lineEnd - lineStart, selectionEnd - lineStart);
  }

  int _getSelectionStartForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    int selectionStart =
        min(editingCore.selectionStart!, editingCore.selectionEnd!);
    int lineStart = editingCore.getLineStartIndex(line);
    return max(0, selectionStart - lineStart);
  }

  bool _isCursorOnLine(int line) {
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return editingCore.cursorPosition >= lineStart &&
        editingCore.cursorPosition <= lineEnd;
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

  void _paintCursor(Canvas canvas, int line, String lineContent) {
    int cursorPositionInLine = _getCursorPositionInLine(line);
    final cursorOffset = textStartX + cursorPositionInLine * charWidth;
    final topY = line * lineHeight * zoomLevel;
    final bottomY = topY + lineHeight * zoomLevel;
    canvas.drawLine(
      Offset(cursorOffset, topY),
      Offset(cursorOffset, bottomY),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 2.0 * zoomLevel,
    );
  }

  void _paintCursorAtEnd(Canvas canvas, int lastLine) {
    final cursorOffset =
        textStartX + _getLineContent(lastLine).length * charWidth;
    final topY = lastLine * lineHeight * zoomLevel;
    final bottomY = topY + lineHeight * zoomLevel;
    canvas.drawLine(
      Offset(cursorOffset, topY),
      Offset(cursorOffset, bottomY),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 2.0 * zoomLevel,
    );
  }

  void _paintSearchHighlights(Canvas canvas, int line, String lineContent) {
    final highlightPaint = Paint()..color = highlightColor;
    final lineStart = editingCore.getLineStartIndex(line);
    final lineEnd = editingCore.getLineEndIndex(line);
    for (int matchPosition in matchPositions) {
      if (matchPosition >= lineStart - 1 && matchPosition < lineEnd) {
        final relativeMatchPosition = matchPosition - lineStart + 1;
        final textBeforeMatch = lineContent.substring(0, relativeMatchPosition);
        final textPainterBefore = TextPainter(
          text: TextSpan(
              text: textBeforeMatch,
              style: textStyle.copyWith(
                  fontSize: textStyle.fontSize! * zoomLevel)),
          textDirection: TextDirection.ltr,
        )..layout();
        final highlightStart = textStartX + textPainterBefore.width;
        final matchText = lineContent.substring(relativeMatchPosition,
            min(relativeMatchPosition + searchTerm.length, lineContent.length));
        final textPainterMatch = TextPainter(
          text: TextSpan(
              text: matchText,
              style: textStyle.copyWith(
                  fontSize: textStyle.fontSize! * zoomLevel)),
          textDirection: TextDirection.ltr,
        )..layout();
        final highlightEnd = highlightStart + textPainterMatch.width;
        final topY = line * lineHeight * zoomLevel;
        final bottomY = topY + lineHeight * zoomLevel;
        canvas.drawRect(
          Rect.fromLTRB(highlightStart, topY, highlightEnd, bottomY),
          highlightPaint,
        );
      }
    }
  }

  void _paintSelection(Canvas canvas, int line, String lineContent) {
    if (!editingCore.hasSelection()) return;
    final selectionPaint = Paint()..color = selectionColor;
    final selectionStart = _getSelectionStartForLine(line);
    final selectionEnd = _getSelectionEndForLine(line);
    final topY = (line * lineHeight * zoomLevel);
    final bottomY = topY + lineHeight * zoomLevel;
    // For empty lines, draw a selection width of 1 character
    final endX = lineContent.isEmpty
        ? textStartX + max(selectionStart, 1) * charWidth
        : textStartX + selectionEnd * charWidth;
    canvas.drawRect(
      Rect.fromLTRB(
        textStartX + selectionStart * charWidth,
        topY,
        endX,
        bottomY,
      ),
      selectionPaint,
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(
          text: text,
          style: textStyle.copyWith(fontSize: textStyle.fontSize! * zoomLevel)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final yOffset =
        offset.dy + (lineHeight * zoomLevel - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(offset.dx, yOffset));
  }
}
