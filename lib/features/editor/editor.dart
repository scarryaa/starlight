import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/gutter/gutter.dart';
import 'package:starlight/features/editor/models/direction.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final f = FocusNode();
  Rope rope = Rope("");
  int absoluteCaretPosition = 0;
  var caretPosition = 0;
  var caretLine = 0;
  static double lineHeight = 0;
  static double charWidth = 0;
  List<int> lineCounts = [0];
  double viewPadding = 100;
  double editorPadding = 5;
  HorizontalDirection horizontalDirection = HorizontalDirection.right;
  VerticalDirection verticalDirection = VerticalDirection.down;
  final EditorScrollManager _scrollManager = EditorScrollManager();
  int selectionStart = -1;
  int selectionEnd = -1;

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Row(children: [
      EditorGutter(
        height: max((lineHeight * rope.lineCount) - editorPadding + viewPadding,
            MediaQuery.of(context).size.height),
        editorVerticalScrollController: _scrollManager.verticalScrollController,
        lineCount: rope.lineCount,
        editorPadding: editorPadding,
      ),
      Expanded(
          child: Scrollbar(
              controller: _scrollManager.horizontalScrollController,
              child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  controller: _scrollManager.horizontalScrollController,
                  child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      scrollDirection: Axis.vertical,
                      controller: _scrollManager.verticalScrollController,
                      child: SizedBox(
                          height: max(
                                  (lineHeight * rope.lineCount) +
                                      viewPadding -
                                      editorPadding,
                                  MediaQuery.of(context).size.height)
                              .toDouble(),
                          width: max(
                              getMaxLineCount() * charWidth +
                                  charWidth +
                                  viewPadding,
                              MediaQuery.of(context).size.width),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                editorPadding, editorPadding, 0, 0),
                            child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTapDown: (TapDownDetails details) =>
                                    f.requestFocus(),
                                child: Focus(
                                    focusNode: f,
                                    onKeyEvent: (node, event) =>
                                        handleInput(event),
                                    child: CustomPaint(
                                      painter: EditorPainter(
                                          // TODO find a better method than splitting the lines
                                          lines: rope.text.split('\n'),
                                          caretPosition: caretPosition,
                                          caretLine: caretLine,
                                          selectionStart: selectionStart,
                                          selectionEnd: selectionEnd,
                                          lineStarts: rope.lineStarts,
                                          text: rope.text),
                                    ))),
                          ))))))
    ]));
  }

  int getMaxLineCount() {
    if (lineCounts.isNotEmpty) return lineCounts.reduce(max);
    return 0;
  }

  void updateLineCounts() {
    lineCounts.clear();
    for (int i = 0; i < rope.lineCount; i++) {
      lineCounts.add(rope.getLineLength(i));
    }
  }

  KeyEventResult handleInput(KeyEvent keyEvent) {
    bool isKeyDownEvent = keyEvent is KeyDownEvent;
    bool isKeyRepeatEvent = keyEvent is KeyRepeatEvent;
    bool isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    bool isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

    if ((isCtrlPressed && !Platform.isMacOS) ||
        (Platform.isMacOS && isMetaPressed) && keyEvent.character != null) {
      setState(() {
        _handleCtrlKeys(keyEvent.character!);
      });
      return KeyEventResult.handled;
    }

    if ((isKeyDownEvent || isKeyRepeatEvent) &&
        keyEvent.character != null &&
        keyEvent.logicalKey != LogicalKeyboardKey.backspace &&
        keyEvent.logicalKey != LogicalKeyboardKey.enter) {
      setState(() {
        // Delete selection if present
        if (selectionStart != selectionEnd) {
          _deleteSelection();
        }

        rope.insert(keyEvent.character!, absoluteCaretPosition);
        caretPosition++;
        absoluteCaretPosition++;

        updateLineCounts();
        _scrollManager.scrollToCursor(
            charWidth,
            caretPosition,
            lineHeight,
            caretLine,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height,
            editorPadding,
            viewPadding,
            horizontalDirection,
            verticalDirection);
      });

      return KeyEventResult.handled;
    } else {
      if ((isKeyDownEvent || isKeyRepeatEvent)) {
        setState(() {
          switch (keyEvent.logicalKey) {
            case LogicalKeyboardKey.backspace:
              handleBackspaceKey();
              horizontalDirection = HorizontalDirection.left;
              verticalDirection = VerticalDirection.up;
              break;
            case LogicalKeyboardKey.enter:
              handleEnterKey();
              verticalDirection = VerticalDirection.down;
              break;
            case LogicalKeyboardKey.arrowLeft:
              handleArrowKeys(LogicalKeyboardKey.arrowLeft);
              horizontalDirection = HorizontalDirection.left;
              break;
            case LogicalKeyboardKey.arrowRight:
              handleArrowKeys(LogicalKeyboardKey.arrowRight);
              horizontalDirection = HorizontalDirection.right;

              break;
            case LogicalKeyboardKey.arrowUp:
              handleArrowKeys(LogicalKeyboardKey.arrowUp);
              verticalDirection = VerticalDirection.up;
              break;
            case LogicalKeyboardKey.arrowDown:
              handleArrowKeys(LogicalKeyboardKey.arrowDown);
              verticalDirection = VerticalDirection.down;
              break;
          }

          updateLineCounts();
          _scrollManager.scrollToCursor(
              charWidth,
              caretPosition,
              lineHeight,
              caretLine,
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
              editorPadding,
              viewPadding,
              horizontalDirection,
              verticalDirection);
        });
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }
  }

  void _deleteSelection() {
    if (selectionStart == -1 ||
        selectionEnd == -1 ||
        selectionStart == selectionEnd) {
      return;
    }

    int start = min(selectionStart, selectionEnd);
    int end = max(selectionStart, selectionEnd);

    rope.delete(start, end - start);

    caretPosition = start;
    absoluteCaretPosition = start;

    caretLine = rope.findClosestLineStart(caretPosition);

    selectionStart = selectionEnd = -1;

    updateLineCounts();

    _scrollManager.scrollToCursor(
        charWidth,
        caretPosition,
        lineHeight,
        caretLine,
        MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height,
        editorPadding,
        viewPadding,
        horizontalDirection,
        verticalDirection);

    // Force a repaint
    setState(() {});
  }

  void _handleCtrlKeys(String key) {
    switch (key) {
      case 'a':
        // Select all
        selectionStart = 0;
        selectionEnd = rope.length - 1;
        break;
      case 'v':
        break;
      case 'c':
        break;
      case 'x':
        break;
    }
  }

  void handleArrowKeys(LogicalKeyboardKey key) {
    setState(() {
      switch (key) {
        case LogicalKeyboardKey.arrowDown:
          moveCaretVertically(1);
          selectionStart = selectionEnd = -1;
          break;
        case LogicalKeyboardKey.arrowUp:
          selectionStart = selectionEnd = -1;
          moveCaretVertically(-1);
          break;
        case LogicalKeyboardKey.arrowLeft:
          selectionStart = selectionEnd = -1;
          moveCaretHorizontally(-1);
          break;
        case LogicalKeyboardKey.arrowRight:
          selectionStart = selectionEnd = -1;
          moveCaretHorizontally(1);
          break;
      }
    });
  }

  void handleBackspaceKey() {
    if (absoluteCaretPosition > 0) {
      // Delete selection if present
      if (selectionStart != selectionEnd) {
        _deleteSelection();
        return;
      }
    }
    {
      if (caretPosition == 0 && caretLine > 0) {
        caretLine--;
        caretPosition = rope.getLineLength(caretLine);
        rope.delete(absoluteCaretPosition - 1, 1); // Delete the newline
        absoluteCaretPosition--;
      } else if (caretPosition > 0) {
        rope.delete(absoluteCaretPosition - 1, 1);
        caretPosition--;
        absoluteCaretPosition--;
      }

      caretLine = max(0, caretLine);
      caretPosition = max(0, min(caretPosition, rope.getLineLength(caretLine)));
      absoluteCaretPosition =
          max(0, min(absoluteCaretPosition, rope.length - 1));
    }
  }

  void handleEnterKey() {
    rope.insert('\n', absoluteCaretPosition);
    caretLine++;
    caretPosition = 0;
    absoluteCaretPosition++;
  }

  void moveCaretHorizontally(int amount) {
    int newCaretPosition = caretPosition + amount;
    int currentLineLength = rope.getLineLength(caretLine);

    if (newCaretPosition >= 0 && newCaretPosition <= currentLineLength) {
      caretPosition = newCaretPosition;
      absoluteCaretPosition += amount;
    } else if (newCaretPosition < 0 && caretLine > 0) {
      caretLine--;
      caretPosition = rope.getLineLength(caretLine);
      absoluteCaretPosition =
          rope.findClosestLineStart(caretLine) + caretPosition;
    } else if (newCaretPosition > currentLineLength &&
        caretLine < rope.lineCount - 1) {
      caretLine++;
      caretPosition = 0;
      absoluteCaretPosition = rope.findClosestLineStart(caretLine);
    }

    absoluteCaretPosition = max(0, min(absoluteCaretPosition, rope.length - 1));
  }

  void moveCaretVertically(int amount) {
    int targetLine = caretLine + amount;
    if (targetLine >= 0 && targetLine < rope.lineCount) {
      int targetLineStart = rope.findClosestLineStart(targetLine);
      int targetLineLength = rope.getLineLength(targetLine);

      if (targetLineLength <= 1) {
        caretPosition = 0;
      } else {
        caretPosition = min(caretPosition, targetLineLength - 1);
      }

      caretLine = targetLine;
      absoluteCaretPosition = targetLineStart + caretPosition;
    }
  }
}

class EditorPainter extends CustomPainter {
  var lines = [];
  var caretPosition = 0;
  var caretLine = 0;
  var charWidth = 0.0;
  double lineHeight = 0.0;
  int selectionStart = 0;
  int selectionEnd = 0;
  List<int> lineStarts = [];
  String text = "";

  EditorPainter(
      {required this.lines,
      required this.caretPosition,
      required this.caretLine,
      required this.selectionStart,
      required this.selectionEnd,
      required this.lineStarts,
      required this.text}) {
    charWidth = _measureCharWidth("w");
    lineHeight = _measureLineHeight("y");

    _EditorState.lineHeight = lineHeight;
    _EditorState.charWidth = charWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < lines.length; i++) {
      TextSpan span = TextSpan(
        text: lines[i],
        style: const TextStyle(
          fontFamily: "Spot Mono",
          color: Colors.black,
          fontSize: 14,
        ),
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: size.width);

      tp.paint(canvas, Offset(0, lineHeight * i));
    }

    // Draw selection
    drawSelection(canvas);

    canvas.drawRect(
        Rect.fromLTWH(caretPosition.toDouble() * charWidth,
            lineHeight * (caretLine + 1) - lineHeight, 2, lineHeight),
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.caretPosition != caretPosition ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd;
  }

  double _measureCharWidth(String s) {
    final textSpan = TextSpan(
      text: s,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontFamily: "Spot Mono",
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.width;
  }

  double _measureLineHeight(String s) {
    final textSpan = TextSpan(
      text: s,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontFamily: "Spot Mono",
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.height;
  }

  void drawSelection(Canvas canvas) {
    if (selectionStart != selectionEnd && lines.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
        if (i >= lineStarts.length) {
          int lineStart =
              (i > 0 ? lineStarts[i - 1] + lines[i - 1].length : 0).toInt();
          int lineEnd = text.length;
          drawSelectionForLine(canvas, i, lineStart, lineEnd);
          continue;
        }

        int lineStart = lineStarts[i];
        int lineEnd;

        if (i < lineStarts.length - 1) {
          lineEnd = lineStarts[i + 1];
        } else {
          lineEnd = text.length;
        }

        drawSelectionForLine(canvas, i, lineStart, lineEnd);
      }
    }
  }

  void drawSelectionForLine(
      Canvas canvas, int lineIndex, int lineStart, int lineEnd) {
    if (lineStart < selectionEnd && lineEnd > selectionStart) {
      double startX = (max(selectionStart, lineStart) - lineStart).toDouble();
      double endX = (min(selectionEnd, lineEnd) - lineStart).toDouble();

      canvas.drawRect(
          Rect.fromLTWH(startX * charWidth, lineHeight * lineIndex,
              (endX - startX) * charWidth, lineHeight),
          Paint()
            ..color = Colors.blue.withOpacity(0.3)
            ..style = PaintingStyle.fill);
    }
  }
}
