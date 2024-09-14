import 'package:flutter/material.dart';

class LineNumberPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;

  LineNumberPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.textStyle,
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
        style: textStyle,
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
  bool shouldRepaint(covariant LineNumberPainter oldDelegate) {
    return lineCount != oldDelegate.lineCount ||
        lineHeight != oldDelegate.lineHeight ||
        lineNumberWidth != oldDelegate.lineNumberWidth ||
        firstVisibleLine != oldDelegate.firstVisibleLine ||
        visibleLineCount != oldDelegate.visibleLineCount ||
        textStyle != oldDelegate.textStyle;
  }
}

class LineNumbers extends StatelessWidget {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;

  const LineNumbers({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: lineNumberWidth,
      child: CustomPaint(
        painter: LineNumberPainter(
          lineCount: lineCount,
          lineHeight: lineHeight,
          lineNumberWidth: lineNumberWidth,
          firstVisibleLine: firstVisibleLine,
          visibleLineCount: visibleLineCount,
          textStyle: textStyle ??
              theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                fontFamily: 'Courier',
              ),
        ),
      ),
    );
  }
}
