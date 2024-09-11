import 'package:flutter/material.dart';

class LineNumbers extends StatelessWidget {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;

  const LineNumbers({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lineNumberWidth,
      child: CustomPaint(
        painter: LineNumberPainter(
          lineCount: lineCount,
          lineHeight: lineHeight,
          lineNumberWidth: lineNumberWidth,
          firstVisibleLine: firstVisibleLine,
          visibleLineCount: visibleLineCount,
        ),
      ),
    );
  }
}

class LineNumberPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;

  LineNumberPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount + 5 && i < lineCount;
        i++) {
      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontFamily: 'Courier',
        ),
      );

      textPainter.layout(maxWidth: lineNumberWidth);

      final double xOffset = (lineNumberWidth - textPainter.width) / 2;
      final double yOffset = (lineHeight - textPainter.height) / 2;

      textPainter.paint(
        canvas,
        Offset(xOffset, i * lineHeight + yOffset),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
