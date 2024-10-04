import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/models/rope.dart';

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

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Scrollbar(
            controller: _horizontalScrollController,
            child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    controller: _verticalScrollController,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (TapDownDetails details) => f.requestFocus(),
                      child: Focus(
                          focusNode: f,
                          onKeyEvent: (node, event) => handleInput(event),
                          child: SizedBox(
                            height: max((lineHeight * rope.lineCount), 400)
                                .toDouble(),
                            width: max(getMaxLineCount() * charWidth, 400) +
                                charWidth,
                            child: CustomPaint(
                              painter: EditorPainter(
                                  // TODO find a better method than splitting the lines
                                  lines: rope.text.split('\n'),
                                  caretPosition: caretPosition,
                                  caretLine: caretLine),
                            ),
                          )),
                    )))));
  }

  int getMaxLineCount() {
    return lineCounts.reduce(max);
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
      });

      return KeyEventResult.handled;
    } else {
      if ((isKeyDownEvent || isKeyRepeatEvent)) {
        setState(() {
          switch (keyEvent.logicalKey) {
            case LogicalKeyboardKey.backspace:
              handleBackspaceKey();
              break;
            case LogicalKeyboardKey.enter:
              handleEnterKey();
              break;
            case LogicalKeyboardKey.arrowLeft:
              handleArrowKeys(LogicalKeyboardKey.arrowLeft);
              break;
            case LogicalKeyboardKey.arrowRight:
              handleArrowKeys(LogicalKeyboardKey.arrowRight);
              break;
            case LogicalKeyboardKey.arrowUp:
              handleArrowKeys(LogicalKeyboardKey.arrowUp);
              break;
            case LogicalKeyboardKey.arrowDown:
              handleArrowKeys(LogicalKeyboardKey.arrowDown);
              break;
          }

          updateLineCounts();
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
      print(rope.text);
    });
  }

  void handleBackspaceKey() {
    if (rope.text.isNotEmpty) {
      if (rope.text[absoluteCaretPosition - 1] == '\n') {
        caretPosition =
            rope.getLineLength(caretLine == 0 ? caretLine : caretLine - 1);
        rope.delete(absoluteCaretPosition - 1);
        caretLine--;
        absoluteCaretPosition =
            caretPosition + rope.findClosestLineStart(caretLine);
      } else {
        rope.delete(absoluteCaretPosition - 1);
        caretPosition--;
        absoluteCaretPosition--;
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
      absoluteCaretPosition = targetPosition;
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

    canvas.drawLine(
        Offset(caretPosition.toDouble() * charWidth,
            lineHeight * (caretLine + 1) - lineHeight),
        Offset(
            caretPosition.toDouble() * charWidth, lineHeight * (caretLine + 1)),
        Paint()..color = Colors.blue);
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
