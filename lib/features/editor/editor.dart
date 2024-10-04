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

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (TapDownDetails details) => f.requestFocus(),
      child: Focus(
        focusNode: f,
        onKeyEvent: (node, event) => handleInput(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPaint(
              painter: EditorPainter(
                  // TODO find a better method than splitting the lines
                  lines: rope.text.split('\n'),
                  caretPosition: caretPosition,
                  caretLine: caretLine),
            ),
          ],
        ),
      ),
    ));
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
  var widthOfChar = 0.0;
  var lineHeight = 0.0;

  EditorPainter(
      {required this.lines,
      required this.caretPosition,
      required this.caretLine}) {
    widthOfChar = _measureCharWidth("w");
    lineHeight = _measureLineHeight("y");
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
        Offset(caretPosition.toDouble() * widthOfChar,
            lineHeight * (caretLine + 1) - lineHeight),
        Offset(caretPosition.toDouble() * widthOfChar,
            lineHeight * (caretLine + 1)),
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
