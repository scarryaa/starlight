import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/models/folding_region.dart';

class LineNumberPainter extends CustomPainter {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;
  final double zoomLevel;
  final List<FoldingRegion> foldingRegions;
  final Function(FoldingRegion) onFoldingToggle;
  final ScrollController scrollController;

  LineNumberPainter({
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.textStyle,
    required this.zoomLevel,
    required this.foldingRegions,
    required this.onFoldingToggle,
    required this.scrollController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );
    final scaledLineHeight = lineHeight * zoomLevel;
    final scaledLineNumberWidth = lineNumberWidth;
    final padding = 4.0 * zoomLevel;

    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount + 5 && i < lineCount;
        i++) {
      // Draw line number
      final lineNumberText = '${i + 1}';
      textPainter.text = TextSpan(
        text: lineNumberText,
        style: textStyle?.copyWith(
          fontSize: (textStyle?.fontSize ?? 12) * zoomLevel,
          color: Colors.grey[600],
        ),
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

      // Draw folding icon if this line is the start of a folding region
      final foldingRegion = foldingRegions.firstWhere(
        (region) =>
            region.startLine ==
            i + 1, // Adjusted to match one-based line numbers
        orElse: () => FoldingRegion(
            startLine: -1, endLine: -1, startColumn: -1, endColumn: -1),
      );
      if (foldingRegion.startLine != -1) {
        final iconSize = scaledLineHeight * 0.6;
        final iconRect = Rect.fromLTWH(
          padding,
          i * scaledLineHeight + (scaledLineHeight - iconSize) / 2,
          iconSize,
          iconSize,
        );
        final iconPaint = Paint()
          ..color =
              foldingRegion.isFolded ? Colors.blue[400]! : Colors.grey[400]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * zoomLevel;

        // Draw chevron
        final path = Path();
        if (foldingRegion.isFolded) {
          // Right-pointing chevron
          path.moveTo(iconRect.left + iconRect.width * 0.3,
              iconRect.top + iconRect.height * 0.25);
          path.lineTo(iconRect.left + iconRect.width * 0.7,
              iconRect.top + iconRect.height * 0.5);
          path.lineTo(iconRect.left + iconRect.width * 0.3,
              iconRect.top + iconRect.height * 0.75);
        } else {
          // Down-pointing chevron
          path.moveTo(iconRect.left + iconRect.width * 0.25,
              iconRect.top + iconRect.height * 0.3);
          path.lineTo(iconRect.left + iconRect.width * 0.5,
              iconRect.top + iconRect.height * 0.7);
          path.lineTo(iconRect.left + iconRect.width * 0.75,
              iconRect.top + iconRect.height * 0.3);
        }
        canvas.drawPath(path, iconPaint);
      }
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
        zoomLevel != oldDelegate.zoomLevel ||
        foldingRegions != oldDelegate.foldingRegions ||
        scrollController != oldDelegate.scrollController;
  }
}

class LineNumbers extends StatefulWidget {
  final int lineCount;
  final double lineHeight;
  final double lineNumberWidth;
  final int firstVisibleLine;
  final int visibleLineCount;
  final TextStyle? textStyle;
  final double zoomLevel;
  final List<FoldingRegion> foldingRegions;
  final Function(FoldingRegion) onFoldingToggle;
  final ScrollController? scrollController; // Make scrollController optional

  const LineNumbers({
    Key? key,
    required this.lineCount,
    required this.lineHeight,
    required this.lineNumberWidth,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.zoomLevel,
    required this.foldingRegions,
    required this.onFoldingToggle,
    this.scrollController, // Optional scrollController
    this.textStyle,
  }) : super(key: key);

  @override
  _LineNumbersState createState() => _LineNumbersState();
}

class _LineNumbersState extends State<LineNumbers> {
  late List<FoldingRegion> _foldingRegions;

  @override
  void initState() {
    super.initState();
    _foldingRegions = widget.foldingRegions;
  }

  @override
  void didUpdateWidget(LineNumbers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.foldingRegions != oldWidget.foldingRegions) {
      _foldingRegions = widget.foldingRegions;
    }
  }

  void _handleFoldToggle(FoldingRegion region) {
    setState(() {
      final index = _foldingRegions.indexOf(region);
      if (index != -1) {
        _foldingRegions[index] = FoldingRegion(
          startLine: region.startLine,
          endLine: region.endLine,
          startColumn: region.startColumn,
          endColumn: region.endColumn,
          isFolded: !region.isFolded,
        );
      }
    });
    widget.onFoldingToggle(region);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaledLineNumberWidth = widget.lineNumberWidth * widget.zoomLevel;

    return GestureDetector(
      onTapDown: (details) => _handleTap(details, context),
      child: Container(
        width: scaledLineNumberWidth,
        color: theme.colorScheme.surface,
        child: CustomPaint(
          painter: LineNumberPainter(
            lineCount: widget.lineCount,
            lineHeight: widget.lineHeight,
            lineNumberWidth: scaledLineNumberWidth,
            firstVisibleLine: widget.firstVisibleLine,
            visibleLineCount: widget.visibleLineCount,
            zoomLevel: widget.zoomLevel,
            textStyle: widget.textStyle ?? theme.textTheme.bodySmall,
            foldingRegions: _foldingRegions,
            onFoldingToggle: _handleFoldToggle,
            scrollController: widget.scrollController ?? ScrollController(),
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details, BuildContext context) {
    final scaledLineHeight = widget.lineHeight * widget.zoomLevel;
    final tappedLineLocal =
        (details.localPosition.dy / scaledLineHeight).floor();

    final scrollOffset = widget.scrollController?.hasClients == true
        ? widget.scrollController!.offset
        : 0.0;

    final tappedLine = tappedLineLocal +
        (scrollOffset / scaledLineHeight).floor() +
        1; // Added +1 here

    final tappedRegion = _foldingRegions.firstWhere(
      (region) => region.startLine == tappedLine,
      orElse: () => FoldingRegion(
          startLine: -1, endLine: -1, startColumn: -1, endColumn: -1),
    );
    if (tappedRegion.startLine != -1) {
      _handleFoldToggle(tappedRegion);
    }
  }
}
