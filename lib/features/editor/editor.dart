import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final f = FocusNode();
  var text = "";

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
              painter: EditorPainter(text: text),
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
        keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
      setState(() {
        text += keyEvent.character!;
      });

      return KeyEventResult.handled;
    } else {
      if ((isKeyDownEvent || isKeyRepeatEvent) &&
          keyEvent.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() {
          text = text.substring(0, text.length - 1);
        });
      }
      return KeyEventResult.ignored;
    }
  }
}

class EditorPainter extends CustomPainter {
  var text = "";
  EditorPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    TextSpan span = TextSpan(
      text: text,
      style: const TextStyle(
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

    tp.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
