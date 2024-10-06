import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:starlight/features/editor/models/direction.dart';

class EditorScrollManager {
  ScrollController horizontalScrollController = ScrollController();
  ScrollController verticalScrollController = ScrollController();

  void scrollTo(Offset offset) {
    horizontalScrollController.jumpTo(offset.dx);
    verticalScrollController.jumpTo(offset.dy);
  }

  bool isCursorInViewHorizontal(
      double charWidth,
      int caretPosition,
      double lineHeight,
      int caretLine,
      double screenWidth,
      double screenHeight,
      double editorPadding,
      double viewPadding,
      HorizontalDirection horizontalDirection,
      VerticalDirection verticalDirection) {
    var horizOffset = (charWidth * caretPosition) + editorPadding * 2.625;

    if (horizOffset > horizontalScrollController.offset &&
        horizontalDirection == HorizontalDirection.right &&
        horizontalScrollController.offset <=
            horizOffset - screenWidth + viewPadding) {
      return false;
    } else if (horizOffset + charWidth - editorPadding * 4 - viewPadding <
            horizontalScrollController.offset &&
        horizontalDirection == HorizontalDirection.left &&
        horizontalScrollController.offset > 0) {
      return false;
    }

    return true;
  }

  bool isCursorInViewVertical(
      double charWidth,
      int caretPosition,
      double lineHeight,
      int caretLine,
      double screenWidth,
      double screenHeight,
      double editorPadding,
      double viewPadding,
      HorizontalDirection horizontalDirection,
      VerticalDirection verticalDirection) {
    var vertOffset = (lineHeight * caretLine) + editorPadding * 3;

    if (vertOffset - screenHeight + viewPadding >
            verticalScrollController.offset &&
        verticalDirection == VerticalDirection.down) {
      return false;
    }
    if (vertOffset <
            verticalScrollController.offset + lineHeight + viewPadding &&
        verticalScrollController.offset > 0 &&
        verticalDirection == VerticalDirection.up) {
      return false;
    }

    return true;
  }

  void scrollToCursorIncremental(
      double charWidth,
      int caretPosition,
      double lineHeight,
      int caretLine,
      double screenWidth,
      double screenHeight,
      double editorPadding,
      double viewPadding,
      HorizontalDirection horizontalDirection,
      VerticalDirection verticalDirection) {
    var horizOffset = (charWidth * caretPosition) + editorPadding * 2.625;
    var vertOffset = (lineHeight * caretLine) + editorPadding * 3;

    // Horizontal scroll (right)
    if (horizOffset >
            horizontalScrollController.offset + screenWidth - viewPadding &&
        horizontalDirection == HorizontalDirection.right) {
      double targetOffset = horizOffset - screenWidth + viewPadding;
      horizontalScrollController.jumpTo(targetOffset);
    }

    // Horizontal scroll (left)
    if (horizOffset < horizontalScrollController.offset + viewPadding &&
        horizontalDirection == HorizontalDirection.left) {
      double targetOffset = horizOffset - viewPadding;
      horizontalScrollController.jumpTo(targetOffset.clamp(
          0.0, horizontalScrollController.position.maxScrollExtent));
    }

    // Vertical scroll (down)
    if (vertOffset >
            verticalScrollController.offset + screenHeight - viewPadding &&
        verticalDirection == VerticalDirection.down) {
      double targetOffset = vertOffset - screenHeight + viewPadding;
      verticalScrollController.jumpTo(targetOffset);
    }

    // Vertical scroll (up)
    if (vertOffset < verticalScrollController.offset + viewPadding &&
        verticalDirection == VerticalDirection.up) {
      double targetOffset = vertOffset - viewPadding;
      verticalScrollController.jumpTo(targetOffset.clamp(
          0.0, verticalScrollController.position.maxScrollExtent));
    }
  }

  void scrollToCursor(
      double charWidth,
      int caretPosition,
      double lineHeight,
      int caretLine,
      double screenWidth,
      double screenHeight,
      double editorPadding,
      double viewPadding,
      HorizontalDirection horizontalDirection,
      VerticalDirection verticalDirection) {
    var horizOffset = (charWidth * caretPosition) + editorPadding * 2.625;
    var vertOffset = (lineHeight * caretLine) + editorPadding * 3;

    if (!isCursorInViewHorizontal(
        charWidth,
        caretPosition,
        lineHeight,
        caretLine,
        screenWidth,
        screenHeight,
        editorPadding,
        viewPadding,
        horizontalDirection,
        verticalDirection)) {
      horizontalScrollController.jumpTo(horizOffset);
    }

    if (!isCursorInViewVertical(
        charWidth,
        caretPosition,
        lineHeight,
        caretLine,
        screenWidth,
        screenHeight,
        editorPadding,
        viewPadding,
        horizontalDirection,
        verticalDirection)) {
      verticalScrollController.jumpTo(vertOffset);
    }
  }

  Future<void> ensureCursorVisible(
    double charWidth,
    int caretPosition,
    double lineHeight,
    int caretLine,
    double editorPadding,
    double viewPadding,
    BuildContext context,
  ) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final caretOffset = Offset(
      charWidth * caretPosition + editorPadding * 2.625,
      lineHeight * caretLine + editorPadding * 3,
    );

    final targetRect = Rect.fromPoints(
      box.localToGlobal(caretOffset),
      box.localToGlobal(caretOffset + Offset(charWidth, lineHeight)),
    );

    await Future.wait([
      _ensureVisible(horizontalScrollController, targetRect,
          horizontal: true, padding: viewPadding),
      _ensureVisible(verticalScrollController, targetRect,
          horizontal: false, padding: viewPadding),
    ]);
  }

  Future<void> _ensureVisible(
    ScrollController controller,
    Rect targetRect, {
    required bool horizontal,
    double alignment = 0.5,
    Duration duration = const Duration(milliseconds: 50),
    Curve curve = Curves.easeInOut,
    double padding = 0,
  }) async {
    if (!controller.hasClients) return;

    final ScrollPosition position = controller.position;
    double leadingEdge = horizontal ? targetRect.left : targetRect.top;
    double trailingEdge = horizontal ? targetRect.right : targetRect.bottom;
    double viewportDimension = position.viewportDimension;

    double targetPixels;
    if (leadingEdge < position.pixels + padding) {
      targetPixels = leadingEdge - viewportDimension * alignment - padding;
    } else if (trailingEdge > position.pixels + viewportDimension - padding) {
      targetPixels =
          trailingEdge - viewportDimension * (1.0 - alignment) + padding;
    } else {
      return;
    }

    await controller.animateTo(
      targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: duration,
      curve: curve,
    );
  }

  void preventOverscroll(double editorPadding, double viewPadding) {
    horizontalScrollController.addListener(
        () => _preventHorizontalOverscroll(editorPadding, viewPadding));
    verticalScrollController.addListener(
        () => _preventVerticalOverscroll(editorPadding, viewPadding));
  }

  void _preventHorizontalOverscroll(double editorPadding, double viewPadding) {
    if (horizontalScrollController.position.outOfRange) {
      if (horizontalScrollController.position.pixels < editorPadding * 2.625) {
        horizontalScrollController.jumpTo(editorPadding * 2.625);
      } else if (horizontalScrollController.position.pixels >
          horizontalScrollController.position.maxScrollExtent -
              editorPadding * 4 -
              viewPadding) {
        horizontalScrollController.jumpTo(
            horizontalScrollController.position.maxScrollExtent -
                editorPadding * 4 -
                viewPadding);
      }
    }
  }

  void _preventVerticalOverscroll(double editorPadding, double viewPadding) {
    if (verticalScrollController.position.outOfRange) {
      if (verticalScrollController.position.pixels < editorPadding * 3) {
        verticalScrollController.jumpTo(editorPadding * 3);
      } else if (verticalScrollController.position.pixels >
          verticalScrollController.position.maxScrollExtent - viewPadding) {
        verticalScrollController.jumpTo(
            verticalScrollController.position.maxScrollExtent - viewPadding);
      }
    }
  }

  ScrollPhysics get clampingScrollPhysics => const ClampingScrollPhysics();
}
