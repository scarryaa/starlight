import 'package:flutter/material.dart';

class LineNumberPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;
  final double zoomLevel;

  LineNumberPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.textStyle,
    required this.zoomLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    final scaledLineHeight = lineHeight * zoomLevel;
    final scaledLineNumberWidth = lineNumberWidth * zoomLevel;
    final padding = 8.0 * zoomLevel;

    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount + 5 && i < lineCount;
        i++) {
      textPainter.text = TextSpan(
        text: '${i + 1}',
        style: textStyle?.copyWith(
            fontSize: (textStyle?.fontSize ?? 14) * zoomLevel),
      );
      textPainter.layout(maxWidth: scaledLineNumberWidth - padding * 2);

      final double xOffset =
          scaledLineNumberWidth - textPainter.width - padding;
      final double yOffset =
          i * scaledLineHeight + (scaledLineHeight - textPainter.height) / 2;

      textPainter.paint(
        canvas,
        Offset(xOffset, yOffset),
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
        textStyle != oldDelegate.textStyle ||
        zoomLevel != oldDelegate.zoomLevel;
  }
}

class LineNumbers extends StatelessWidget {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;
  final double zoomLevel;

  const LineNumbers({
    super.key,
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.zoomLevel,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaledLineNumberWidth = lineNumberWidth * zoomLevel;

    return SizedBox(
      width: scaledLineNumberWidth,
      child: CustomPaint(
        painter: LineNumberPainter(
          lineCount: lineCount,
          lineHeight: lineHeight,
          lineNumberWidth: lineNumberWidth,
          firstVisibleLine: firstVisibleLine,
          visibleLineCount: visibleLineCount,
          zoomLevel: zoomLevel,
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
