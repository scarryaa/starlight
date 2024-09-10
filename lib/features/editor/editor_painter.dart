import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditorPainter extends CustomPainter {
  static const double lineHeight = 24.0;
  static const double charWidth = 10.0;
  static const double lineNumberWidth = 50.0;

  final TextEditingCore editingCore;
  final int firstVisibleLine;
  final int visibleLineCount;
  final double horizontalOffset;
  final int version; // Add this line

  final TextStyle _lineNumberStyle =
      TextStyle(fontSize: 14, color: Colors.grey[600]);
  final TextStyle _textStyle =
      const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Courier');

  CodeEditorPainter({
    required this.editingCore,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.horizontalOffset,
    required this.version, // Add this line
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount;
        i++) {
      if (i >= editingCore.getLineCount()) break;

      final lineContent = editingCore.getLineContent(i);
      final lineNumber =
          '${i + 1}'.padLeft(editingCore.getLineCount().toString().length);

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
      if (i == editingCore.cursorLine) {
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

    final textPainter = TextPainter(
      text: TextSpan(text: lineContent, style: _textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final startOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selectionStart), Rect.zero);
    final endOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selectionEnd), Rect.zero);

    canvas.drawRect(
      Rect.fromLTRB(
        lineNumberWidth + startOffset.dx - horizontalOffset,
        line * lineHeight,
        lineNumberWidth + endOffset.dx - horizontalOffset,
        (line + 1) * lineHeight,
      ),
      selectionPaint,
    );
  }

  void _paintCursor(Canvas canvas, int line, String lineContent) {
    final cursorPosition = min(editingCore.cursorColumn, lineContent.length);
    final textPainter = TextPainter(
      text: TextSpan(
          text: lineContent.substring(0, cursorPosition), style: _textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final cursorOffset = textPainter.width;
    canvas.drawLine(
      Offset(
          lineNumberWidth + cursorOffset - horizontalOffset, line * lineHeight),
      Offset(lineNumberWidth + cursorOffset - horizontalOffset,
          (line + 1) * lineHeight),
      Paint()..color = Colors.blue,
    );
  }

  bool _isLineSelected(int line) {
    if (!editingCore.hasSelection()) return false;
    return line >=
            min(editingCore.selectionStartLine!,
                editingCore.selectionEndLine!) &&
        line <=
            max(editingCore.selectionStartLine!, editingCore.selectionEndLine!);
  }

  int _getSelectionStartForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    if (editingCore.selectionStartLine! > editingCore.selectionEndLine! ||
        (editingCore.selectionStartLine == editingCore.selectionEndLine &&
            editingCore.selectionStartColumn! >
                editingCore.selectionEndColumn!)) {
      return line == editingCore.selectionEndLine!
          ? editingCore.selectionEndColumn!
          : 0;
    }
    return line == editingCore.selectionStartLine!
        ? editingCore.selectionStartColumn!
        : 0;
  }

  int _getSelectionEndForLine(int line) {
    if (!editingCore.hasSelection()) return 0;
    if (editingCore.selectionStartLine! > editingCore.selectionEndLine! ||
        (editingCore.selectionStartLine == editingCore.selectionEndLine &&
            editingCore.selectionStartColumn! >
                editingCore.selectionEndColumn!)) {
      return line == editingCore.selectionStartLine!
          ? editingCore.selectionStartColumn!
          : editingCore.getLineContent(line).length;
    }
    return line == editingCore.selectionEndLine!
        ? editingCore.selectionEndColumn!
        : editingCore.getLineContent(line).length;
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
