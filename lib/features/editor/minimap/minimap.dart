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
    super.key,
    required this.rope,
    required this.verticalController,
    required this.editorHeight,
    required this.lineHeight,
    required this.currentLine,
    required this.syntaxHighlighter,
  });

  @override
  State<EditorMinimap> createState() => _EditorMinimapState();
}

class _EditorMinimapState extends State<EditorMinimap> {
  static const double _scrollMultiplier = 0.5;
  static const double _minScrollAmount = 1.0;
  static const double _miniMapWidth = 100.0;
  late MinimapCache _minimapCache;
  double? _dragStartScrollOffset;
  double? _dragStartY;

  @override
  void initState() {
    super.initState();
    widget.verticalController.addListener(_handleScroll);
    _updateMinimapCache();
  }

  @override
  void didUpdateWidget(EditorMinimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rope != widget.rope ||
        oldWidget.editorHeight != widget.editorHeight ||
        oldWidget.lineHeight != widget.lineHeight) {
      _updateMinimapCache();
    }
  }

  void _updateMinimapCache() {
    _minimapCache = MinimapCache(
      rope: widget.rope,
      syntaxHighlighter: widget.syntaxHighlighter,
      editorHeight: widget.editorHeight,
      lineHeight: widget.lineHeight,
    );
  }

  @override
  void dispose() {
    widget.verticalController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) setState(() {});
  }

  void _handleMinimapDragStart(DragStartDetails details) {
    _dragStartScrollOffset = widget.verticalController.hasClients
        ? widget.verticalController.offset
        : null;
    _dragStartY = details.localPosition.dy;
  }

  void _handleMinimapDragUpdate(DragUpdateDetails details) {
    if (!widget.verticalController.hasClients ||
        _dragStartScrollOffset == null ||
        _dragStartY == null) return;

    final miniMapScale = _calculateMinimapScale();
    final dragDistance =
        (details.localPosition.dy - _dragStartY!) / miniMapScale;
    final newScrollPosition = _dragStartScrollOffset! + dragDistance;

    _scrollToPosition(newScrollPosition);
  }

  void _handleMinimapDragEnd(DragEndDetails details) {
    _dragStartScrollOffset = _dragStartY = null;
  }

  void _handleMouseWheel(PointerSignalEvent event) {
    if (event is PointerScrollEvent && widget.verticalController.hasClients) {
      final scrollDelta = event.scrollDelta.dy;
      final viewportDimension =
          widget.verticalController.position.viewportDimension;

      final scaleFactor = widget.editorHeight / viewportDimension;
      var scrollAmount = scrollDelta * scaleFactor * _scrollMultiplier;

      if (scrollAmount.abs() < _minScrollAmount) {
        scrollAmount = scrollAmount.sign * _minScrollAmount;
      }

      final newScrollPosition = widget.verticalController.offset + scrollAmount;
      _scrollToPosition(newScrollPosition);
    }
  }

  void _scrollToPosition(double position) {
    final maxScrollExtent = widget.verticalController.position.maxScrollExtent;
    final clampedPosition = position.clamp(0.0, maxScrollExtent);
    widget.verticalController.jumpTo(clampedPosition);
  }

  double _calculateMinimapScale() => min(0.1, 300 / widget.editorHeight);

  @override
  Widget build(BuildContext context) {
    if (!widget.verticalController.hasClients) {
      return const SizedBox.shrink();
    }

    final miniMapScale = _calculateMinimapScale();
    final miniMapHeight = widget.editorHeight * miniMapScale;

    return Container(
      width: _miniMapWidth,
      height: miniMapHeight,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
      ),
      child: Listener(
        onPointerSignal: _handleMouseWheel,
        child: GestureDetector(
          onVerticalDragStart: _handleMinimapDragStart,
          onVerticalDragUpdate: _handleMinimapDragUpdate,
          onVerticalDragEnd: _handleMinimapDragEnd,
          onTapDown: _handleTapDown,
          child: CustomPaint(
            size: Size(_miniMapWidth, miniMapHeight),
            painter: MinimapPainter(
              minimapCache: _minimapCache,
              scale: miniMapScale,
              scrollOffset: widget.verticalController.hasClients
                  ? widget.verticalController.offset
                  : 0,
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

  void _handleTapDown(TapDownDetails details) {
    _handleMinimapDragStart(
        DragStartDetails(localPosition: details.localPosition));
    _handleMinimapDragUpdate(DragUpdateDetails(
      globalPosition: details.globalPosition,
      localPosition: details.localPosition,
    ));
    _handleMinimapDragEnd(DragEndDetails());
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
    return List.generate(rope.lineCount, (i) {
      final lineContent = rope.getLine(i);
      final highlightedSpans =
          syntaxHighlighter.highlightSyntax(lineContent, false);
      return highlightedSpans
          .map((span) =>
              MinimapSpan(span.text!, span.style?.color ?? Colors.white))
          .toList();
    });
  }
}

class MinimapSpan {
  final String text;
  final Color color;

  const MinimapSpan(this.text, this.color);
}

class MinimapPainter extends CustomPainter {
  final MinimapCache minimapCache;
  final double scale;
  final double scrollOffset;
  final double viewportHeight;
  final double editorHeight;
  final int currentLine;

  const MinimapPainter({
    required this.minimapCache,
    required this.scale,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.editorHeight,
    required this.currentLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final contentHeight =
        minimapCache.rope.lineCount * minimapCache.lineHeight * scale;
    final scaleFactor =
        contentHeight < size.height ? 1.0 : size.height / contentHeight;

    _drawMinimapContent(canvas, size, scaleFactor.toDouble());
    _drawViewportIndicator(canvas, size, scaleFactor.toDouble());
    _drawCurrentLineIndicator(canvas, size, scaleFactor.toDouble());
  }

  void _drawMinimapContent(Canvas canvas, Size size, double scaleFactor) {
    for (int i = 0; i < minimapCache.cachedLines.length; i++) {
      final yPosition = i * minimapCache.lineHeight * scale * scaleFactor;
      if (yPosition > size.height) break;
      _drawHighlightedLine(
          canvas, minimapCache.cachedLines[i], yPosition, size.width);
    }
  }

  void _drawViewportIndicator(Canvas canvas, Size size, double scaleFactor) {
    final contentHeight =
        minimapCache.rope.lineCount * minimapCache.lineHeight * scale;
    final actualHeight = min<double>(contentHeight, size.height).toDouble();
    final viewportRatio = viewportHeight / editorHeight;
    final indicatorHeight = actualHeight * viewportRatio;

    final maxScrollOffset = max(0, editorHeight - viewportHeight);
    final scrollRatio =
        maxScrollOffset > 0 ? scrollOffset / maxScrollOffset : 0.0;
    final indicatorTop = scrollRatio * (actualHeight - indicatorHeight);

    final indicatorPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, indicatorTop.toDouble(), size.width, indicatorHeight),
      indicatorPaint,
    );
  }

  void _drawCurrentLineIndicator(Canvas canvas, Size size, double scaleFactor) {
    final currentLineY =
        currentLine * minimapCache.lineHeight * scale * scaleFactor;
    canvas.drawRect(
      Rect.fromLTWH(0, currentLineY, size.width,
          minimapCache.lineHeight * scale * scaleFactor),
      Paint()
        ..color = Colors.lightBlue.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawHighlightedLine(Canvas canvas, List<MinimapSpan> spans,
      double yPosition, double maxWidth) {
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

