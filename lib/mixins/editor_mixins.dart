import 'dart:math';
import 'package:flutter/material.dart';
import 'package:starlight/features/editor/domain/enums/selection_mode.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/utils/constants.dart';

mixin CodeEditorScrollMixin<T extends StatefulWidget> on State<T> {
  late ScrollController codeScrollController;
  late ScrollController lineNumberScrollController;
  late ScrollController horizontalController;
  late ScrollController horizontalScrollbarController;
  bool _scrollingCode = false;
  bool _scrollingLineNumbers = false;
  bool _isHorizontalScrolling = false;

  late TextEditingCore editingCore;
  late int firstVisibleLine;
  late int visibleLineCount;
  late double lineNumberWidth;
  late double zoomLevel;

  @override
  void initState() {
    super.initState();
    initializeScrollControllers();
  }

  @override
  void dispose() {
    disposeScrollControllers();
    super.dispose();
  }

  void initializeScrollControllers() {
    codeScrollController = ScrollController()..addListener(_onCodeScroll);
    lineNumberScrollController = ScrollController()
      ..addListener(_onLineNumberScroll);
    horizontalController = ScrollController()..addListener(_onHorizontalScroll);
    horizontalScrollbarController = ScrollController()
      ..addListener(_syncHorizontalScrollbar);
  }

  void disposeScrollControllers() {
    codeScrollController.dispose();
    lineNumberScrollController.dispose();
    horizontalController.dispose();
    horizontalScrollbarController.dispose();
  }

  void _onCodeScroll() {
    if (!_scrollingCode && !_scrollingLineNumbers) {
      _scrollingCode = true;
      lineNumberScrollController.jumpTo(codeScrollController.offset);
      _scrollingCode = false;
      updateVisibleLines();
      setState(() {});
    }
  }

  void _onLineNumberScroll() {
    if (!_scrollingLineNumbers && !_scrollingCode) {
      _scrollingLineNumbers = true;
      codeScrollController.jumpTo(lineNumberScrollController.offset);
      _scrollingLineNumbers = false;
      updateVisibleLines();
      setState(() {});
    }
  }

  void _onHorizontalScroll() {
    if (!_isHorizontalScrolling &&
        horizontalController.hasClients &&
        horizontalScrollbarController.hasClients) {
      _isHorizontalScrolling = true;
      horizontalScrollbarController.jumpTo(horizontalController.offset);
      _isHorizontalScrolling = false;
      setState(() {});
    }
  }

  void _syncHorizontalScrollbar() {
    if (!_isHorizontalScrolling &&
        horizontalScrollbarController.hasClients &&
        horizontalController.hasClients) {
      _isHorizontalScrolling = true;
      horizontalController.jumpTo(horizontalScrollbarController.offset);
      _isHorizontalScrolling = false;
    }
  }

  void updateVisibleLines() {
    if (!mounted || !codeScrollController.hasClients) return;
    final totalLines = editingCore.lineCount;
    final viewportHeight = codeScrollController.position.viewportDimension;
    firstVisibleLine = (codeScrollController.offset /
            (CodeEditorConstants.lineHeight * zoomLevel))
        .floor()
        .clamp(0, totalLines == 0 ? 0 : totalLines - 1);
    visibleLineCount =
        (viewportHeight / (CodeEditorConstants.lineHeight * zoomLevel)).ceil() +
            1;
    if (firstVisibleLine + visibleLineCount > totalLines) {
      visibleLineCount = totalLines - firstVisibleLine;
    }
  }

  void autoScrollOnDrag(Offset position) {
    const scrollThreshold = 50.0;
    final scrollStep = 16.0 * zoomLevel;
    if (position.dy < scrollThreshold && codeScrollController.offset > 0) {
      codeScrollController
          .jumpTo(max(0, codeScrollController.offset - scrollStep));
    } else if (position.dy > context.size!.height - scrollThreshold &&
        codeScrollController.offset <
            codeScrollController.position.maxScrollExtent) {
      codeScrollController.jumpTo(min(
        codeScrollController.position.maxScrollExtent,
        codeScrollController.offset + scrollStep,
      ));
    }

    if (position.dx < scrollThreshold && horizontalController.offset > 0) {
      horizontalController
          .jumpTo(max(0, horizontalController.offset - scrollStep));
    } else if (position.dx > context.size!.width - scrollThreshold &&
        horizontalController.offset <
            horizontalController.position.maxScrollExtent) {
      horizontalController.jumpTo(min(
        horizontalController.position.maxScrollExtent,
        horizontalController.offset + scrollStep,
      ));
    }
  }

  void ensureCursorVisibility() {
    if (!codeScrollController.hasClients || !horizontalController.hasClients) {
      return;
    }

    final cursorPosition =
        editingCore.cursorPosition.clamp(0, editingCore.length);
    int cursorLine = editingCore.rope.findLine(cursorPosition);
    int lineStartIndex = editingCore.getLineStartIndex(cursorLine);
    int cursorColumn = cursorPosition - lineStartIndex;

    // Vertical scrolling
    final cursorY = cursorLine * CodeEditorConstants.lineHeight * zoomLevel;
    if (cursorY < codeScrollController.offset) {
      codeScrollController.jumpTo(cursorY);
    } else if (cursorY >
        codeScrollController.offset +
            codeScrollController.position.viewportDimension -
            CodeEditorConstants.lineHeight * zoomLevel) {
      codeScrollController.jumpTo(cursorY -
          codeScrollController.position.viewportDimension +
          CodeEditorConstants.lineHeight * zoomLevel);
    }

    // Horizontal scrolling
    final cursorX = cursorColumn * CodeEditorConstants.charWidth * zoomLevel +
        lineNumberWidth * zoomLevel;
    if (cursorX < horizontalController.offset + lineNumberWidth * zoomLevel) {
      horizontalController.jumpTo(cursorX - lineNumberWidth * zoomLevel);
    } else if (cursorX >
        horizontalController.offset +
            horizontalController.position.viewportDimension -
            CodeEditorConstants.charWidth * zoomLevel) {
      horizontalController.jumpTo(cursorX -
          horizontalController.position.viewportDimension +
          CodeEditorConstants.charWidth * zoomLevel);
    }

    // Ensure the entire selection is visible
    if (editingCore.hasSelection()) {
      final selectionStart = editingCore.selectionStart!;
      final selectionEnd = editingCore.selectionEnd!;
      final startLine = editingCore.rope.findLine(selectionStart);
      final endLine = editingCore.rope.findLine(selectionEnd);
      final startColumn =
          selectionStart - editingCore.getLineStartIndex(startLine);
      final endColumn = selectionEnd - editingCore.getLineStartIndex(endLine);

      // Vertical scrolling for selection
      final startY = startLine * CodeEditorConstants.lineHeight;
      final endY = (endLine + 1) * CodeEditorConstants.lineHeight;
      if (startY < codeScrollController.offset) {
        codeScrollController.jumpTo(startY);
      } else if (endY >
          codeScrollController.offset +
              codeScrollController.position.viewportDimension) {
        codeScrollController
            .jumpTo(endY - codeScrollController.position.viewportDimension);
      }

      // Horizontal scrolling for selection
      final startX =
          startColumn * CodeEditorConstants.charWidth + lineNumberWidth;
      final endX = endColumn * CodeEditorConstants.charWidth + lineNumberWidth;
      if (startX < horizontalController.offset + lineNumberWidth) {
        horizontalController.jumpTo(startX - lineNumberWidth);
      } else if (endX >
          horizontalController.offset +
              horizontalController.position.viewportDimension) {
        horizontalController.jumpTo(endX -
            horizontalController.position.viewportDimension +
            CodeEditorConstants.charWidth);
      }
    }
  }

  int getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(
            max(0, horizontalController.offset), codeScrollController.offset);
    final tappedLine =
        (adjustedOffset.dy / (CodeEditorConstants.lineHeight * zoomLevel))
            .floor();

    if (editingCore.lineCount == 0) return 0;
    if (tappedLine < editingCore.lineCount) {
      final scaledLineNumberWidth = lineNumberWidth * zoomLevel;
      final textStartX = scaledLineNumberWidth / 8;
      final adjustedTappedOffset =
          (adjustedOffset.dx - textStartX).clamp(0, double.infinity);
      final column =
          (adjustedTappedOffset / (CodeEditorConstants.charWidth * zoomLevel))
              .round()
              .clamp(0, double.infinity)
              .toInt();

      if (tappedLine < 0) return 0;
      int lineStartIndex = editingCore.getLineStartIndex(tappedLine);
      String line = editingCore.getLineContent(tappedLine);
      if (line.isEmpty) return lineStartIndex;
      if (column >= line.length) {
        return lineStartIndex + line.length;
      }
      return lineStartIndex + column;
    }
    return editingCore.length;
  }

  void resetAllScrollPositions() {
    setState(() {
      if (codeScrollController.hasClients) {
        codeScrollController.jumpTo(0);
      }
      if (lineNumberScrollController.hasClients) {
        lineNumberScrollController.jumpTo(0);
      }
      if (horizontalController.hasClients) {
        horizontalController.jumpTo(0);
      }
      if (horizontalScrollbarController.hasClients) {
        horizontalScrollbarController.jumpTo(0);
      }
    });
  }
}
mixin CodeEditorSelectionMixin<T extends StatefulWidget> on State<T> {
  final SelectionMode _selectionMode = SelectionMode.character;
  int? _selectionAnchor;

  void _updateSelection(DragStartDetails details) {}

  void _updateSelectionOnDrag(DragUpdateDetails details) {}

  void _selectWordAtPosition(int position) {}

  void _selectLineAtPosition(int position) {}
}

mixin CodeEditorKeyboardHandlerMixin<T extends StatefulWidget> on State<T> {
  // KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
  // }

  // bool _handleShortcuts(KeyEvent event) {
  // }

  // bool _handleSelectionKeys(KeyEvent event) {
  // }

  // bool _handleTextInputKeys(KeyEvent event) {
  // }
}

mixin CodeEditorClipboardMixin<T extends StatefulWidget> on State<T> {
  void _handleCopy() async {}

  void _handleCut() async {}

  void _handlePaste() async {}
}

mixin CodeEditorCalculationMixin<T extends StatefulWidget> on State<T> {
  void _calculateLineNumberWidth() {}

  void _updateMaxLineWidth() {}

  void _updateVisibleLines() {}
}
