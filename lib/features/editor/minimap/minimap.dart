import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/syntax_highlighting_service.dart';

class EditorMinimap extends StatefulWidget {
  final Rope rope;
  final ScrollController verticalController;
  final double editorHeight;
  final double lineHeight;
  final int currentLine;
  final SyntaxHighlightingService syntaxHighlighter;

  const EditorMinimap({
    Key? key,
    required this.rope,
    required this.verticalController,
    required this.editorHeight,
    required this.lineHeight,
    required this.currentLine,
    required this.syntaxHighlighter,
  }) : super(key: key);

  @override
  State<EditorMinimap> createState() => _EditorMinimapState();
}

class _EditorMinimapState extends State<EditorMinimap> {
  static const double _scrollMultiplier = 0.5;
  static const double _minScrollAmount = 1.0;
  late MinimapCache _minimapCache;
  double? _dragStartScrollOffset;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    widget.verticalController.addListener(_handleScroll);
    _minimapCache = MinimapCache(
      rope: widget.rope,
      syntaxHighlighter: widget.syntaxHighlighter,
      editorHeight: widget.editorHeight,
      lineHeight: widget.lineHeight,
    );
  }

  @override
  void didUpdateWidget(EditorMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rope != widget.rope ||
        oldWidget.editorHeight != widget.editorHeight ||
        oldWidget.lineHeight != widget.lineHeight) {
      _minimapCache = MinimapCache(
        rope: widget.rope,
        syntaxHighlighter: widget.syntaxHighlighter,
        editorHeight: widget.editorHeight,
        lineHeight: widget.lineHeight,
      );
    }
  }

  @override
  void dispose() {
    widget.verticalController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleMinimapDragStart(DragStartDetails details) {
    _dragStartScrollOffset = widget.verticalController.offset;
    _dragStartY = details.localPosition.dy;
  }

  void _handleMinimapDragUpdate(DragUpdateDetails details) {
    if (!widget.verticalController.hasClients || _dragStartScrollOffset == null || _dragStartY == null) return;

    final miniMapScale = min(0.1, 300 / widget.editorHeight);
    final miniMapHeight = widget.editorHeight * miniMapScale;

    // Calculate the drag distance in the full-size editor scale
    final dragDistance = (details.localPosition.dy - _dragStartY!) / miniMapScale;

    // Calculate the new scroll position
    final newScrollPosition = _dragStartScrollOffset! + dragDistance;

    // Clamp the new position to the valid range
    final clampedPosition = newScrollPosition.clamp(
      0.0,
      widget.verticalController.position.maxScrollExtent,
    );

    // Jump to the new position
    widget.verticalController.jumpTo(clampedPosition);
  }

  void _handleMinimapDragEnd(DragEndDetails details) {
    _dragStartScrollOffset = null;
    _dragStartY = null;
  }

  void _handleMouseWheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent && widget.verticalController.hasClients) {
      final scrollDelta = event.scrollDelta.dy;
      final scaleFactor = widget.editorHeight / widget.verticalController.position.viewportDimension;
      var scrollAmount = scrollDelta * scaleFactor * _scrollMultiplier;

      if (scrollAmount.abs() < _minScrollAmount) {
        scrollAmount = scrollAmount.sign * _minScrollAmount;
      }

      final newScrollPosition = widget.verticalController.offset + scrollAmount;
      final clampedPosition = newScrollPosition.clamp(
        0.0,
        widget.verticalController.position.maxScrollExtent,
      );

      widget.verticalController.jumpTo(clampedPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final miniMapScale = min(0.1, 300 / widget.editorHeight);
    const miniMapWidth = 100.0;
    final miniMapHeight = widget.editorHeight * miniMapScale;

    return SizedBox(
      width: miniMapWidth,
      height: miniMapHeight,
      child: Listener(
        onPointerSignal: _handleMouseWheel,
        child: GestureDetector(
          onVerticalDragStart: _handleMinimapDragStart,
          onVerticalDragUpdate: _handleMinimapDragUpdate,
          onVerticalDragEnd: _handleMinimapDragEnd,
          onTapDown: (TapDownDetails details) {
            _handleMinimapDragStart(DragStartDetails(localPosition: details.localPosition));
            _handleMinimapDragUpdate(DragUpdateDetails(
              globalPosition: details.globalPosition,
              localPosition: details.localPosition,
            ));
            _handleMinimapDragEnd(DragEndDetails());
          },
          child: CustomPaint(
            size: Size(miniMapWidth, miniMapHeight),
            painter: MinimapPainter(
              minimapCache: _minimapCache,
              scale: miniMapScale,
              scrollOffset: widget.verticalController.hasClients
                  ? widget.verticalController.offset
                  : 0.0,
              viewportHeight: widget.verticalController.hasClients
                  ? widget.verticalController.position.viewportDimension
                  : 0,
              editorHeight: widget.editorHeight,
              currentLine: widget.currentLine,
            ),
          ),
        ),
      ),
    );
  }
}
class MinimapCache {
  final Rope rope;
  final SyntaxHighlightingService syntaxHighlighter;
  final double editorHeight;
  final double lineHeight;
  late final List<List<MinimapSpan>> cachedLines;

  MinimapCache({
    required this.rope,
    required this.syntaxHighlighter,
    required this.editorHeight,
    required this.lineHeight,
  }) {
    cachedLines = _generateCache();
  }

  List<List<MinimapSpan>> _generateCache() {
    final List<List<MinimapSpan>> cache = [];
    for (int i = 0; i < rope.lineCount; i++) {
      final lineContent = rope.getLine(i);
      final highlightedSpans = syntaxHighlighter.highlightSyntax(lineContent, false);
      cache.add(highlightedSpans.map((span) => MinimapSpan(span.text!, span.style?.color ?? Colors.white)).toList());
    }
    return cache;
  }
}

class MinimapSpan {
  final String text;
  final Color color;

  MinimapSpan(this.text, this.color);
}

class MinimapPainter extends CustomPainter {
  final MinimapCache minimapCache;
  final double scale;
  final double scrollOffset;
  final double viewportHeight;
  final double editorHeight;
  final int currentLine;

  MinimapPainter({
    required this.minimapCache,
    required this.scale,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.editorHeight,
    required this.currentLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleFactor = size.height / editorHeight;

    // Draw the minimap content
    for (int i = 0; i < minimapCache.cachedLines.length; i++) {
      final yPosition = i * minimapCache.lineHeight * scaleFactor;
      if (yPosition > size.height) break;
      drawHighlightedLine(canvas, minimapCache.cachedLines[i], yPosition, size.width);
    }

    // Draw the viewport indicator
    final viewportRatio = viewportHeight / editorHeight;
    final indicatorHeight = size.height * viewportRatio;

    final scrollRatio = scrollOffset / (editorHeight - viewportHeight);
    final indicatorTop = scrollRatio * (size.height - indicatorHeight);

    final indicatorPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, indicatorTop, size.width, indicatorHeight),
      indicatorPaint,
    );

    // Draw current line indicator
    final currentLineY = currentLine * minimapCache.lineHeight * scaleFactor;
    canvas.drawRect(
      Rect.fromLTWH(0, currentLineY, size.width, minimapCache.lineHeight * scaleFactor),
      Paint()
        ..color = Colors.yellow.withOpacity(0.5)
        ..style = PaintingStyle.fill,
    );
  }

  void drawHighlightedLine(Canvas canvas, List<MinimapSpan> spans, double yPosition, double maxWidth) {
    double xOffset = 0.0;

    for (final span in spans) {
      final lineWidth = (span.text.length / 100) * maxWidth;
      final actualWidth = min(lineWidth, maxWidth - xOffset);

      if (actualWidth <= 0) break;

      final paint = Paint()
        ..color = span.color.withOpacity(0.5)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(xOffset, yPosition, actualWidth, 1),
        paint,
      );

      xOffset += actualWidth;
      if (xOffset >= maxWidth) break;
    }
  }

  @override
  bool shouldRepaint(covariant MinimapPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.editorHeight != editorHeight ||
        oldDelegate.viewportHeight != viewportHeight ||
        oldDelegate.currentLine != currentLine ||
        oldDelegate.minimapCache != minimapCache;
  }
}
