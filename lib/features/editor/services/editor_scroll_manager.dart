import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:starlight/features/editor/models/direction.dart';

class EditorScrollManager {
  void scrollTo(ScrollController horizontalController,
      ScrollController verticalController, Offset offset) {
    horizontalController.jumpTo(offset.dx);
    verticalController.jumpTo(offset.dy);
  }

  bool isCursorInViewHorizontal(
      ScrollController controller,
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
    var horizOffset = (charWidth * caretPosition);

    if (horizOffset > controller.offset &&
        horizontalDirection == HorizontalDirection.right &&
        controller.offset <= horizOffset - screenWidth + viewPadding) {
      return false;
    } else if (horizOffset + charWidth - editorPadding * 4 - viewPadding <
            controller.offset &&
        horizontalDirection == HorizontalDirection.left &&
        controller.offset > 0) {
      return false;
    }

    return true;
  }

  bool isCursorInViewVertical(
      ScrollController controller,
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

    if (vertOffset - screenHeight + viewPadding > controller.offset &&
        verticalDirection == VerticalDirection.down) {
      return false;
    }
    if (vertOffset < controller.offset + lineHeight + viewPadding &&
        controller.offset > 0 &&
        verticalDirection == VerticalDirection.up) {
      return false;
    }

    return true;
  }

  void scrollToCursorIncremental(
      ScrollController horizontalController,
      ScrollController verticalController,
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
    if (horizOffset > horizontalController.offset + screenWidth - viewPadding &&
        horizontalDirection == HorizontalDirection.right) {
      double targetOffset = horizOffset - screenWidth + viewPadding;
      horizontalController.jumpTo(targetOffset);
    }

    // Horizontal scroll (left)
    if (horizOffset < horizontalController.offset + viewPadding &&
        horizontalDirection == HorizontalDirection.left) {
      double targetOffset = horizOffset - viewPadding;
      horizontalController.jumpTo(targetOffset.clamp(
          0.0, horizontalController.position.maxScrollExtent));
    }

    // Vertical scroll (down)
    if (vertOffset > verticalController.offset + screenHeight - viewPadding &&
        verticalDirection == VerticalDirection.down) {
      double targetOffset = vertOffset - screenHeight + viewPadding;
      verticalController.jumpTo(targetOffset);
    }

    // Vertical scroll (up)
    if (vertOffset < verticalController.offset + viewPadding &&
        verticalDirection == VerticalDirection.up) {
      double targetOffset = vertOffset - viewPadding;
      verticalController.jumpTo(
          targetOffset.clamp(0.0, verticalController.position.maxScrollExtent));
    }
  }

  void scrollToCursor(
      ScrollController horizontalController,
      ScrollController verticalController,
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
        horizontalController,
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
      horizontalController.jumpTo(horizOffset);
    }

    if (!isCursorInViewVertical(
        verticalController,
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
      verticalController.jumpTo(vertOffset);
    }
  }

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
      _ensureVisible(horizontalController, targetRect,
          horizontal: true, padding: viewPadding),
      _ensureVisible(verticalController, targetRect,
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

  void preventOverscroll(
      ScrollController horizontalController,
      ScrollController verticalController,
      double editorPadding,
      double viewPadding) {
    horizontalController.addListener(() => _preventHorizontalOverscroll(
        horizontalController, editorPadding, viewPadding));
    verticalController.addListener(() => _preventVerticalOverscroll(
        verticalController, editorPadding, viewPadding));
  }

  void _preventHorizontalOverscroll(
      ScrollController controller, double editorPadding, double viewPadding) {
    if (controller.position.outOfRange) {
      if (controller.position.pixels < editorPadding * 2.625) {
        controller.jumpTo(editorPadding * 2.625);
      } else if (controller.position.pixels >
          controller.position.maxScrollExtent -
              editorPadding * 4 -
              viewPadding) {
        controller.jumpTo(controller.position.maxScrollExtent -
            editorPadding * 4 -
            viewPadding);
      }
    }
  }

  void _preventVerticalOverscroll(
      ScrollController controller, double editorPadding, double viewPadding) {
    if (controller.position.outOfRange) {
      if (controller.position.pixels < editorPadding * 3) {
        controller.jumpTo(editorPadding * 3);
      } else if (controller.position.pixels >
          controller.position.maxScrollExtent - viewPadding) {
        controller.jumpTo(controller.position.maxScrollExtent - viewPadding);
      }
    }
  }

  ScrollPhysics get clampingScrollPhysics => const ClampingScrollPhysics();
}
