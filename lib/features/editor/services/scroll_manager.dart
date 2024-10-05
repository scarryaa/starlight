import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:starlight/features/editor/models/direction.dart';

class ScrollManager {
  ScrollController horizontalScrollController = ScrollController();
  ScrollController verticalScrollController = ScrollController();

  void scrollTo(Offset offset) {
    horizontalScrollController.jumpTo(offset.dx);
    verticalScrollController.jumpTo(offset.dy);
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
    var vertOffset = (lineHeight * caretLine) + editorPadding * 4;
    var offset = Offset(horizOffset, vertOffset);

    // Horizontal scroll (right)
    if (horizOffset > horizontalScrollController.offset &&
        horizontalDirection == HorizontalDirection.right &&
        horizontalScrollController.offset <=
            offset.dx - screenWidth + viewPadding) {
      horizontalScrollController
          .jumpTo(horizontalScrollController.offset + charWidth);
    }

    // (left)
    if (horizOffset + charWidth - editorPadding * 4 - viewPadding <
            horizontalScrollController.offset &&
        horizontalDirection == HorizontalDirection.left &&
        horizontalScrollController.offset > 0) {
      horizontalScrollController
          .jumpTo((horizontalScrollController.offset - charWidth));
    }

    // Vertical scroll (down)
    if (vertOffset > screenHeight &&
        verticalDirection == VerticalDirection.down) {
      verticalScrollController.jumpTo(offset.dy - screenHeight + viewPadding);
    }

    // (up)
    if (vertOffset > screenHeight - verticalScrollController.offset &&
        verticalDirection == VerticalDirection.up) {
      verticalScrollController.jumpTo(offset.dy - screenHeight + viewPadding);
    }
  }
}
