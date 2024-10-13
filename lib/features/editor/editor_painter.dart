import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/editor_content.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/syntax_highlighting_service.dart';
import 'package:starlight/services/theme_manager.dart';

class EditorPainter extends CustomPainter {
  final List<String> lines;
  final int caretPosition;
  final int caretLine;
  final int selectionStart;
  final int selectionEnd;
  final List<int> lineStarts;
  final String text;
  late double charWidth;
  late double lineHeight;
  double horizontalOffset;
  double verticalOffset;
  double viewportHeight;
  double viewportWidth;
  final String fontFamily;
  final double fontSize;
  final int lastUpdatedLine;
  final int currentLineIndex;
  final BuildContext buildContext;
  final SyntaxHighlightingService highlightingService =
      SyntaxHighlightingService();
  final bool isDarkMode;
  final Color codeBlockLineColor;
  final double codeBlockLineWidth = 1.0;
  late List<List<int>> indentationLevels;
  final List<int>? matchingBrackets;
  Rope rope;
  SyntaxHighlightingService syntaxHighlighter;
  bool isDragging = false;
  final bool isSearchVisible;
  final String searchQuery;
  final List<int> matchPositions;
  final int currentMatch;
  final List<int> selectedMatches;

  EditorPainter({
    required this.lines,
    required this.caretPosition,
    required this.caretLine,
    required this.selectionStart,
    required this.selectionEnd,
    required this.lineStarts,
    required this.text,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.viewportHeight,
    required this.viewportWidth,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontSize,
    required this.lastUpdatedLine,
    required this.currentLineIndex,
    required this.buildContext,
    required this.matchingBrackets,
    required this.rope,
    required this.isDragging,
    required this.syntaxHighlighter,
    required this.isSearchVisible,
    required this.searchQuery,
    required this.matchPositions,
    required this.currentMatch,
    required this.selectedMatches,
  })  : isDarkMode = Provider.of<ThemeManager>(buildContext, listen: false)
                    .themeMode ==
                ThemeMode.dark ||
            (Provider.of<ThemeManager>(buildContext, listen: false).themeMode ==
                    ThemeMode.system &&
                MediaQuery.of(buildContext).platformBrightness ==
                    Brightness.dark),
        codeBlockLineColor =
            (Provider.of<ThemeManager>(buildContext, listen: false).themeMode ==
                        ThemeMode.dark ||
                    (Provider.of<ThemeManager>(buildContext, listen: false)
                                .themeMode ==
                            ThemeMode.system &&
                        MediaQuery.of(buildContext).platformBrightness ==
                            Brightness.dark))
                ? Colors.grey[800]!.withOpacity(0.3) // Dark mode color
                : Colors.grey.withOpacity(0.05), // Light mode color
        super() {
    charWidth = _measureCharWidth("w");
    lineHeight = _measureLineHeight("y");

    EditorContentState.lineHeight = lineHeight;
    EditorContentState.charWidth = charWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final themeManager = Provider.of<ThemeManager>(buildContext, listen: false);
    final theme = Theme.of(buildContext);
    final isDarkMode = themeManager.themeMode == ThemeMode.dark ||
        (themeManager.themeMode == ThemeMode.system &&
            MediaQuery.of(buildContext).platformBrightness == Brightness.dark);

    final selectionColor = theme.colorScheme.primary.withOpacity(0.3);
    final caretColor = theme.colorScheme.primary;
    final currentLineColor = theme.colorScheme.primary.withOpacity(0.1);

    int firstVisibleLine = max((verticalOffset / lineHeight).floor(), 0);
    int lastVisibleLine = min(
        firstVisibleLine + (viewportHeight / lineHeight).ceil(), lines.length);

    if (lines.isNotEmpty) {
      indentationLevels = calculateIndentationLevels();
      for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
        if (i < lines.length) {
          drawCodeBlockLines(canvas, firstVisibleLine, lastVisibleLine, size);

          List<TextSpan> highlightedSpans =
              highlightingService.highlightSyntax(lines[i], isDarkMode);
          TextSpan span = TextSpan(
            children: highlightedSpans,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              height: 1,
            ),
          );
          TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: size.width);

          double yPosition =
              (lineHeight * i) + ((lineHeight - tp.height) / 1.3);
          tp.paint(canvas, Offset(0, yPosition));
        }
      }
    }

    highlightCurrentLine(canvas, currentLineIndex, size, currentLineColor);
    drawSelection(canvas, firstVisibleLine, lastVisibleLine, selectionColor);

    // Draw caret
    if (caretLine >= firstVisibleLine &&
        caretLine < lastVisibleLine &&
        caretLine < lines.length) {
      canvas.drawRect(
        Rect.fromLTWH(
          caretPosition * charWidth,
          lineHeight * caretLine,
          2,
          lineHeight,
        ),
        Paint()
          ..color = caretColor
          ..style = PaintingStyle.fill,
      );
    }

    // Draw search highlights
    if (isSearchVisible && searchQuery.isNotEmpty) {
      drawSearchHighlights(canvas, size);
    }

    // Draw bracket and quote highlighting
    if (matchingBrackets != null &&
        !isDragging &&
        !(selectionStart != selectionEnd)) {
      final bracketHighlightColor = theme.colorScheme.primary.withOpacity(0.4);

      for (int position in matchingBrackets!) {
        int line = rope.findLineForPosition(position);
        int column = position - rope.findClosestLineStart(line);
        String bracketChar = rope.charAt(position);

        // Draw highlight rectangle
        canvas.drawRect(
          Rect.fromLTWH(
            column * charWidth,
            line * lineHeight,
            charWidth,
            lineHeight,
          ),
          Paint()
            ..color = bracketHighlightColor
            ..style = PaintingStyle.fill,
        );

        // Draw the bracket or quote character
        TextPainter charPainter = TextPainter(
          text: TextSpan(
            text: bracketChar,
            style: TextStyle(
              color: invertColor(bracketHighlightColor),
              fontSize: fontSize,
              fontFamily: fontFamily,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        charPainter.layout();
        charPainter.paint(
          canvas,
          Offset(
            column * charWidth + (charWidth - charPainter.width) / 2,
            line * lineHeight + (lineHeight - charPainter.height) / 2,
          ),
        );
      }
    }
  }

  void drawSearchHighlights(Canvas canvas, Size size) {
    final searchHighlightColor = Colors.yellow.withOpacity(0.3);
    final currentMatchColor = Colors.orange.withOpacity(0.5);
    final selectedMatchColor = Colors.green.withOpacity(0.3);

    int firstVisibleLine = (verticalOffset / lineHeight).floor();
    int lastVisibleLine =
        ((verticalOffset + viewportHeight) / lineHeight).ceil();

    for (int i = 0; i < matchPositions.length; i++) {
      int position = matchPositions[i];
      int line = rope.findLineForPosition(position);

      // Only draw highlights for visible lines
      if (line < firstVisibleLine || line > lastVisibleLine) {
        continue;
      }

      int column = position - rope.findClosestLineStart(line);

      Color highlightColor = searchHighlightColor;
      if (i == currentMatch - 1) {
        highlightColor = currentMatchColor;
      } else if (selectedMatches.contains(position)) {
        highlightColor = selectedMatchColor;
      }

      canvas.drawRect(
        Rect.fromLTWH(
          column * charWidth,
          (line * lineHeight),
          searchQuery.length * charWidth,
          lineHeight,
        ),
        Paint()..color = highlightColor,
      );
    }
  }

  Color invertColor(Color color) {
    final r = 255 - color.red;
    final g = 255 - color.green;
    final b = 255 - color.blue;
    return Color.fromARGB(color.alpha, r, g, b);
  }

  List<List<int>> calculateIndentationLevels() {
    List<List<int>> levels = [];
    List<int> indentStack = [0];
    int previousIndent = 0;

    for (String line in lines) {
      int indent = getIndentation(line);
      List<int> currentLevels = [];

      if (indent > previousIndent) {
        indentStack.add(indent);
      } else if (indent < previousIndent) {
        while (indentStack.isNotEmpty && indentStack.last > indent) {
          indentStack.removeLast();
        }
      }

      for (int i = 0; i < indentStack.length - 1; i++) {
        currentLevels.add(indentStack[i]);
      }

      levels.add(currentLevels);
      previousIndent = indent;
    }

    return levels;
  }

  void drawCodeBlockLines(
      Canvas canvas, int firstVisibleLine, int lastVisibleLine, Size size) {
    List<int> activeIndents = [];
    Map<int, double> indentStartY = {};

    for (int i = 0; i < firstVisibleLine && i < lines.length; i++) {
      updateActiveIndents(activeIndents, getIndentation(lines[i]));
    }

    for (int i = firstVisibleLine;
        i < lastVisibleLine && i < lines.length;
        i++) {
      int currentIndent = getIndentation(lines[i]);
      double y = lineHeight * i;

      // Remove any indents that are greater than the current indent
      List<int> endingIndents =
          activeIndents.where((indent) => indent > currentIndent).toList();
      for (int indent in endingIndents) {
        if (indentStartY.containsKey(indent)) {
          double startY = indentStartY[indent]!;
          canvas.drawLine(
              Offset(indent * charWidth - 15, startY),
              Offset(indent * charWidth - 15, y),
              Paint()
                ..color = codeBlockLineColor
                ..strokeWidth = codeBlockLineWidth);
          indentStartY.remove(indent);
        }
        activeIndents.remove(indent);
      }

      // Add the current indent if it's not already in activeIndents
      if (currentIndent > 0 && !activeIndents.contains(currentIndent)) {
        activeIndents.add(currentIndent);
        indentStartY[currentIndent] = y;
      }

      // Update the start Y for indents that are still active but not present in this line
      for (int indent in activeIndents) {
        if (indent < currentIndent && !indentStartY.containsKey(indent)) {
          indentStartY[indent] = y;
        }
      }
    }

    // Draw remaining active indents to the bottom of the visible area
    double bottomY = lineHeight * lastVisibleLine;
    for (int indent in activeIndents) {
      if (indentStartY.containsKey(indent)) {
        double startY = indentStartY[indent]!;
        canvas.drawLine(
            Offset(indent * charWidth - 15, startY),
            Offset(indent * charWidth - 15, bottomY),
            Paint()
              ..color = codeBlockLineColor
              ..strokeWidth = codeBlockLineWidth);
      }
    }
  }

  void updateActiveIndents(List<int> activeIndents, int currentIndent) {
    // Remove any indents that are greater than the current indent
    activeIndents.removeWhere((indent) => indent > currentIndent);

    // Add the current indent if it's not already in activeIndents
    if (currentIndent > 0 && !activeIndents.contains(currentIndent)) {
      activeIndents.add(currentIndent);
    }
  }

  int getIndentation(String line) {
    int spaces = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        spaces++;
      } else if (line[i] == '\t') {
        spaces += 4;
      } else {
        break;
      }
    }
    return spaces;
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.caretPosition != caretPosition ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd ||
        oldDelegate.caretLine != caretLine ||
        oldDelegate.verticalOffset != verticalOffset ||
        oldDelegate.horizontalOffset != horizontalOffset ||
        oldDelegate.viewportHeight != viewportHeight ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.charWidth != charWidth ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.lastUpdatedLine != lastUpdatedLine ||
        oldDelegate.lineStarts != lineStarts ||
        oldDelegate.text != text ||
        oldDelegate.matchingBrackets != matchingBrackets ||
        oldDelegate.isSearchVisible != isSearchVisible ||
        oldDelegate.searchQuery != searchQuery ||
        oldDelegate.matchPositions != matchPositions ||
        oldDelegate.currentMatch != currentMatch;
  }

  double _measureCharWidth(String s) {
    final textSpan = TextSpan(
      text: s,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.white,
        fontFamily: fontFamily,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.width;
  }

  double _measureLineHeight(String s) {
    final textSpan = TextSpan(
      text: s,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: Colors.white,
        fontFamily: fontFamily,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.height;
  }

  void drawSelection(Canvas canvas, int firstVisibleLine, int lastVisibleLine,
      Color selectionColor) {
    if (selectionStart != selectionEnd && lines.isNotEmpty) {
      for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
        if (i >= lineStarts.length) {
          int lineStart =
              (i > 0 ? lineStarts[i - 1] + lines[i - 1].length : 0).toInt();
          int lineEnd = text.length;
          drawSelectionForLine(canvas, i, lineStart, lineEnd, selectionColor);
          continue;
        }

        int lineStart = lineStarts[i];
        int lineEnd =
            i < lineStarts.length - 1 ? lineStarts[i + 1] - 1 : text.length;

        // For empty lines that are not the last line, print a 1 char selection
        if (lineEnd - lineStart == 0) {
          lineEnd++;
        }

        drawSelectionForLine(canvas, i, lineStart, lineEnd, selectionColor);
      }
    }
  }

  void highlightCurrentLine(
      Canvas canvas, int currentLineIndex, Size size, Color highlightColor) {
    canvas.drawRect(
        Rect.fromLTWH(0, lineHeight * currentLineIndex, size.width, lineHeight),
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.fill);
  }

  void drawSelectionForLine(Canvas canvas, int lineIndex, int lineStart,
      int lineEnd, Color selectionColor) {
    if (lineStart < selectionEnd && lineEnd > selectionStart) {
      double startX = (max(selectionStart, lineStart) - lineStart).toDouble();
      double endX = (min(selectionEnd, lineEnd) - lineStart).toDouble();

      canvas.drawRect(
        Rect.fromLTWH(
          startX * charWidth,
          lineHeight * lineIndex,
          (endX - startX) * charWidth,
          lineHeight,
        ),
        Paint()
          ..color = selectionColor
          ..style = PaintingStyle.fill,
      );
    }
  }
}
