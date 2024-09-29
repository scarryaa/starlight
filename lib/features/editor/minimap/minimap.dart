import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/services/syntax_highlighter.dart';

class Minimap extends StatefulWidget {
  final TextEditingCore editingCore;
  final SyntaxHighlighter syntaxHighlighter;
  final ScrollController scrollController;
  final double viewportHeight;
  final double editorHeight;
  final double zoomLevel;

  const Minimap({
    super.key,
    required this.editingCore,
    required this.syntaxHighlighter,
    required this.scrollController,
    required this.viewportHeight,
    required this.editorHeight,
    required this.zoomLevel,
  });

  @override
  _MinimapState createState() => _MinimapState();
}

class _MinimapState extends State<Minimap> {
  static const double _scrollMultiplier = 0.5;
  static const double _minScrollAmount = 1.0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(Minimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorHeight != widget.editorHeight ||
        oldWidget.viewportHeight != widget.viewportHeight) {}
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleMinimapDrag(DragUpdateDetails details) {
    if (!widget.scrollController.hasClients) return;

    final miniMapScale = min(0.1, 300 / widget.editorHeight);
    final miniMapHeight = widget.editorHeight * miniMapScale;

    final viewportRatio = widget.viewportHeight / widget.editorHeight;
    final indicatorHeight = miniMapHeight * viewportRatio;
    final mousePositionInMinimap = details.localPosition.dy;
    final centerOffset = indicatorHeight / 2;

    final targetScrollPosition =
        ((mousePositionInMinimap - centerOffset) / miniMapHeight) *
            widget.editorHeight;

    final clampedPosition = targetScrollPosition.clamp(
      0.0,
      widget.scrollController.position.maxScrollExtent,
    );

    widget.scrollController.jumpTo(clampedPosition);
  }

  void _handleMouseWheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent && widget.scrollController.hasClients) {
      final scrollDelta = event.scrollDelta.dy;
      final scaleFactor =
          widget.editorHeight / (widget.viewportHeight * widget.zoomLevel);
      var scrollAmount = scrollDelta * scaleFactor * _scrollMultiplier;

      if (scrollAmount.abs() < _minScrollAmount) {
        scrollAmount = scrollAmount.sign * _minScrollAmount;
      }

      final newScrollPosition = widget.scrollController.offset + scrollAmount;
      final clampedPosition = newScrollPosition.clamp(
        0.0,
        widget.scrollController.position.maxScrollExtent,
      );

      widget.scrollController.jumpTo(clampedPosition);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final miniMapScale = min(0.1, 300 / widget.editorHeight);
    const miniMapWidth = 100.0;
    final miniMapHeight = widget.editorHeight * miniMapScale;

    return Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: miniMapWidth,
        height: miniMapHeight,
        child: Listener(
          onPointerSignal: _handleMouseWheel,
          child: GestureDetector(
            onVerticalDragUpdate: _handleMinimapDrag,
            onTapDown: (TapDownDetails details) {
              _handleMinimapDrag(DragUpdateDetails(
                globalPosition: details.globalPosition,
                localPosition: details.localPosition,
              ));
            },
            child: CustomPaint(
              size: Size(miniMapWidth, miniMapHeight),
              painter: MinimapPainter(
                editingCore: widget.editingCore,
                syntaxHighlighter: widget.syntaxHighlighter,
                scale: miniMapScale,
                zoomLevel: widget.zoomLevel,
                scrollOffset: widget.scrollController.hasClients
                    ? widget.scrollController.offset
                    : 0.0,
                viewportHeight: widget.viewportHeight,
                editorHeight: widget.editorHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }
}

class MinimapPainter extends CustomPainter {
  final TextEditingCore editingCore;
  final SyntaxHighlighter syntaxHighlighter;
  final double scale;
  final double zoomLevel;
  final double scrollOffset;
  final double viewportHeight;
  final double editorHeight;

  MinimapPainter({
    required this.editingCore,
    required this.syntaxHighlighter,
    required this.scale,
    required this.zoomLevel,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.editorHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const lineHeight = 1.0;
    final totalLines = editingCore.lineCount;
    final maxWidth = size.width;

    for (int i = 0; i < totalLines; i++) {
      final lineContent = editingCore.getLineContent(i);
      final yPosition = i * lineHeight;

      if (yPosition > size.height) break;

      drawHighlightedLine(canvas, lineContent, yPosition, maxWidth, i);
    }

    final viewportRatio = viewportHeight / editorHeight;
    final indicatorHeight = size.height * viewportRatio;

    final scrollRatio = scrollOffset / editorHeight;
    final indicatorTop = scrollRatio * size.height;

    final indicatorPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, indicatorTop, size.width, indicatorHeight),
      indicatorPaint,
    );
  }

  void drawHighlightedLine(Canvas canvas, String lineContent, double yPosition,
      double maxWidth, int lineNumber) {
    if (lineContent.isEmpty) return;

    final highlightedSpans = syntaxHighlighter.highlightLine(
        lineContent, lineNumber, editingCore.version);
    double xOffset = 0.0;

    for (final span in highlightedSpans) {
      final text = span.text!;
      final color = span.style?.color ?? Colors.white;
      final lineWidth = (text.length / 100) * maxWidth;
      final actualWidth = min(lineWidth, maxWidth - xOffset);

      if (actualWidth <= 0) break;

      final paint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(xOffset, yPosition, actualWidth, 1),
        paint,
      );

      xOffset += actualWidth;
      if (xOffset >= maxWidth) break;
    }
  }

  void drawLine(
      Canvas canvas, String lineContent, double yPosition, double maxWidth) {
    if (lineContent.isEmpty) return;

    final lineWidth = (lineContent.length / 100) * maxWidth;
    final actualWidth = min(lineWidth, maxWidth);

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, yPosition, actualWidth, 1),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant MinimapPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.editorHeight != editorHeight ||
        oldDelegate.viewportHeight != viewportHeight ||
        oldDelegate.editingCore.version != editingCore.version;
  }
}
