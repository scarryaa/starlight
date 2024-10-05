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
                                        caretLine: caretLine),
                                  ),
                                )),
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
    var isKeyDownEvent = keyEvent is KeyDownEvent;
    var isKeyRepeatEvent = keyEvent is KeyRepeatEvent;

    if ((isKeyDownEvent || isKeyRepeatEvent) &&
        keyEvent.character != null &&
        keyEvent.logicalKey != LogicalKeyboardKey.backspace &&
        keyEvent.logicalKey != LogicalKeyboardKey.enter) {
      setState(() {
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

  void handleArrowKeys(LogicalKeyboardKey key) {
    setState(() {
      switch (key) {
        case LogicalKeyboardKey.arrowDown:
          moveCaretVertically(1);
          break;
        case LogicalKeyboardKey.arrowUp:
          moveCaretVertically(-1);
          break;
        case LogicalKeyboardKey.arrowLeft:
          moveCaretHorizontally(-1);
          break;
        case LogicalKeyboardKey.arrowRight:
          moveCaretHorizontally(1);
          break;
      }
    });
  }

  void handleBackspaceKey() {
    if (caretPosition > 0 || caretLine != 0) {
      if (rope.text.isNotEmpty) {
        if (rope.text[absoluteCaretPosition - 1] == '\n' &&
            absoluteCaretPosition != 0) {
          caretPosition =
              rope.getLineLength(caretLine == 0 ? caretLine : caretLine - 1);
          rope.delete(absoluteCaretPosition - 1);
          caretLine--;
          absoluteCaretPosition = caretPosition +
              rope.findClosestLineStart(caretLine) +
              1 -
              (caretLine == 0 ? 1 : 0);
        } else {
          rope.delete(absoluteCaretPosition - 1);
          caretPosition--;
          absoluteCaretPosition--;
        }
      }
    }
  }

  void handleEnterKey() {
    rope.insert('\n', absoluteCaretPosition);
    caretPosition = 0;
    absoluteCaretPosition++;
    caretLine++;
  }

  moveCaretHorizontally(int amount) {
    if (caretPosition + amount >= 0 &&
        absoluteCaretPosition + amount <= rope.text.length &&
        caretPosition + amount <= rope.getLineLength(caretLine)) {
      caretPosition += amount;
      absoluteCaretPosition += amount;
    }
  }

  void moveCaretVertically(int amount) {
    int targetLine = caretLine + amount;
    if (targetLine >= 0 && targetLine < rope.lineCount) {
      int targetLineStart = rope.findClosestLineStart(targetLine);
      int targetLineLength = rope.getLineLength(targetLine);

      int targetPosition = min(
          targetLineStart + caretPosition, targetLineStart + targetLineLength);
      absoluteCaretPosition = targetPosition + 1;
      caretLine = targetLine;
      caretPosition = targetPosition - targetLineStart;
    }
  }
}

class EditorPainter extends CustomPainter {
  var lines = [];
  var caretPosition = 0;
  var caretLine = 0;
  var charWidth = 0.0;
  double lineHeight = 0.0;

  EditorPainter(
      {required this.lines,
      required this.caretPosition,
      required this.caretLine}) {
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
        oldDelegate.caretPosition != caretPosition;
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
}
