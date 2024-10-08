import 'package:flutter/material.dart' hide VerticalDirection;

class EditorScrollManager {
  static const int _scrollAnimationDuration = 200;
  static const double _gutterWidth = 40.0;
  static const double _verticalBuffer = 2.0;
 
 Future<void> ensureCursorVisible(
    ScrollController horizontalController,
    ScrollController verticalController,
    double charWidth,
    int caretPosition,
    double lineHeight,
    int caretLine,
    double editorPadding,
    double viewPadding,
    BuildContext context,
  ) async {
    if (!horizontalController.hasClients || !verticalController.hasClients) {
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Size viewportSize = box.size;

    final double caretX = charWidth * caretPosition + editorPadding;
    final double caretY = lineHeight * caretLine + editorPadding;

    await Future.wait([
      _ensureVisibleHorizontal(
        horizontalController,
        caretX,
        charWidth,
        viewportSize.width,
        editorPadding,
        viewPadding,
      ),
      _ensureVisibleVertical(
        verticalController,
        caretY,
        lineHeight,
        viewportSize.height,
        editorPadding,
        viewPadding,
      ),
    ]);
  }

  Future<void> _ensureVisibleHorizontal(
    ScrollController controller,
    double caretX,
    double charWidth,
    double viewportWidth,
    double editorPadding,
    double viewPadding,
  ) async {
    final double effectiveViewportWidth = viewportWidth - _gutterWidth - viewPadding;
    final double leftEdge = controller.offset + _gutterWidth + editorPadding;
    final double rightEdge = leftEdge + effectiveViewportWidth - charWidth;

    if (caretX < leftEdge) {
      await _animateScrollTo(
        controller,
        caretX - _gutterWidth - editorPadding,
      );
    } else if (caretX > rightEdge) {
      await _animateScrollTo(
        controller,
        caretX - effectiveViewportWidth + charWidth + editorPadding,
      );
    }
  }

  Future<void> _ensureVisibleVertical(
    ScrollController controller,
    double caretY,
    double lineHeight,
    double viewportHeight,
    double editorPadding,
    double viewPadding,
  ) async {
    final double effectiveViewportHeight = viewportHeight - viewPadding;
    final double topBufferSize = lineHeight * _verticalBuffer;
    final double topEdge = controller.offset + editorPadding + topBufferSize;
    final double bottomEdge = topEdge + effectiveViewportHeight - lineHeight - topBufferSize;

    if (caretY < topEdge) {
      await _animateScrollTo(
        controller,
        caretY - editorPadding - topBufferSize,
      );
    } else if (caretY > bottomEdge) {
      await _animateScrollTo(
        controller,
        caretY - effectiveViewportHeight + lineHeight + editorPadding + topBufferSize,
      );
    }
  }

  Future<void> _animateScrollTo(ScrollController controller, double position) {
    return controller.animateTo(
      position,
      duration: const Duration(milliseconds: _scrollAnimationDuration),
      curve: Curves.easeOutCubic,
    );
  }

  void preventOverscroll(
    ScrollController horizontalController,
    ScrollController verticalController,
    double editorPadding,
    double viewPadding,
  ) {
    horizontalController.addListener(() => _preventOverscroll(
      horizontalController,
      editorPadding,
      viewPadding,
      isHorizontal: true,
    ));
    verticalController.addListener(() => _preventOverscroll(
      verticalController,
      editorPadding,
      viewPadding,
      isHorizontal: false,
    ));
  }

  void _preventOverscroll(
    ScrollController controller,
    double editorPadding,
    double viewPadding, {
    required bool isHorizontal,
  }) {
    if (!controller.position.outOfRange) return;

    double minScroll = editorPadding;
    double maxScroll = controller.position.maxScrollExtent - 
        (isHorizontal ? editorPadding : viewPadding);

    if (controller.position.pixels < minScroll) {
      controller.jumpTo(minScroll);
    } else if (controller.position.pixels > maxScroll) {
      controller.jumpTo(maxScroll);
    }
  }

  ScrollPhysics get clampingScrollPhysics => const ClampingScrollPhysics();
}
