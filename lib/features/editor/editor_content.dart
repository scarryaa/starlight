import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/gutter/gutter.dart';
import 'package:starlight/features/editor/models/direction.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/models/selection_mode.dart';
import 'package:starlight/features/editor/services/editor_keyboard_handler.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';

class EditorContent extends StatefulWidget {
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final EditorScrollManager scrollManager;
  final EditorSelectionManager editorSelectionManager;
  final HotkeyService hotkeyService;
  final CustomTab.Tab tab;
  final FileService fileService;
  final TabService tabService;
  final double lineHeight;
  final String fontFamily;
  final double fontSize;
  final int tabSize;

  const EditorContent({
    super.key,
    required this.verticalController,
    required this.horizontalController,
    required this.scrollManager,
    required this.tab,
    required this.fileService,
    required this.tabService,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontSize,
    required this.tabSize,
    required this.hotkeyService,
    required this.editorSelectionManager,
  });

  @override
  State<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<EditorContent> {
  int _lastUpdatedLine = 0;
  final FocusNode f = FocusNode();
  late Rope rope;
  static double lineHeight = 0;
  static double charWidth = 0;
  List<int> lineCounts = [0];
  double viewPadding = 100;
  double editorPadding = 5;
  HorizontalDirection horizontalDirection = HorizontalDirection.right;
  VerticalDirection verticalDirection = VerticalDirection.down;
  double _verticalOffset = 0;
  double _horizontalOffset = 0;
  Key _painterKey = UniqueKey();
  bool _isDragging = false;
  int _dragStartPosition = -1;
  late Size _editorSize;
  int _clickCount = 0;
  int _lastClickTime = 0;
  static const int _doubleClickTime = 300; // milliseconds
  late EditorKeyboardHandler keyboardHandler;

  @override
  void initState() {
    super.initState();
    rope = Rope(widget.tab.content);
    updateLineCounts();
    widget.scrollManager.preventOverscroll(widget.horizontalController,
        widget.verticalController, editorPadding, viewPadding);
    widget.verticalController.addListener(_handleVerticalScroll);
    widget.horizontalController.addListener(_handleHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentSize());

    keyboardHandler = EditorKeyboardHandler(
      rope: rope,
      tabService: widget.tabService,
      hotkeyService: widget.hotkeyService,
      selectionManager: widget.editorSelectionManager,
      updateSelection: (start, end) {
        setState(() {
          widget.editorSelectionManager.selectionStart = start;
          widget.editorSelectionManager.selectionEnd = end;
        });
      },
      updateLineCounts: () {
        setState(() {
          updateLineCounts();
        });
      },
      saveFile: saveFile,
      ensureCursorVisible: () {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureCursorVisible();
        });
      },
      updateAfterEdit: updateAfterEdit,
      notifyListeners: () => setState(() {}),
    );
  }

  @override
  void dispose() {
    widget.verticalController.removeListener(_handleVerticalScroll);
    widget.horizontalController.removeListener(_handleHorizontalScroll);
    super.dispose();
  }

  void _handleVerticalScroll() {
    setState(() {
      _verticalOffset = widget.verticalController.offset;
    });
  }

  void _handleHorizontalScroll() {
    setState(() {
      _horizontalOffset = widget.horizontalController.offset;
    });
  }

  void _updateContentSize() {
    setState(() {
      // Update the content size and scroll extent
      WidgetsBinding.instance.addPostFrameCallback(
        (timeStamp) {
          widget.verticalController.jumpTo(widget.verticalController.offset);
          widget.horizontalController
              .jumpTo(widget.horizontalController.offset);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentHeight = max(
          (lineHeight * rope.lineCount) + viewPadding,
          MediaQuery.of(context).size.height,
        ) -
        35;

    return Row(
      children: [
        EditorGutter(
          currentLine: keyboardHandler.caretLine,
          fontSize: widget.fontSize,
          fontFamily: widget.fontFamily,
          height: contentHeight,
          lineHeight: lineHeight,
          editorVerticalScrollController: widget.verticalController,
          lineCount: rope.lineCount,
          editorPadding: editorPadding,
          viewPadding: viewPadding,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification) {
                _handleScroll();
              }
              return true;
            },
            child: GestureDetector(
              onTapDown: (TapDownDetails details) {
                f.requestFocus();
                _handleTap(details);
              },
              onPanStart: (DragStartDetails details) {
                f.requestFocus();
                handleDragStart(details);
              },
              onPanUpdate: (DragUpdateDetails details) {
                f.requestFocus();
                handleDragUpdate(details);
              },
              onPanEnd: (DragEndDetails details) {
                f.requestFocus();
                handleDragEnd(details);
              },
              behavior: HitTestBehavior.translucent,
              child: Focus(
                focusNode: f,
                onKeyEvent: (node, event) {
                  var result = keyboardHandler.handleInput(event);
                  setState(() {
                    _lastUpdatedLine = keyboardHandler.lastUpdatedLine;
                  });
                  return result;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _editorSize = Size(constraints.maxWidth, contentHeight);

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: RawScrollbar(
                            controller: widget.horizontalController,
                            thumbVisibility: true,
                            thickness: 8,
                            radius: const Radius.circular(4),
                            thumbColor: Colors.grey.withOpacity(0.5),
                            minThumbLength: 30,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: SingleChildScrollView(
                              physics:
                                  widget.scrollManager.clampingScrollPhysics,
                              controller: widget.verticalController,
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                physics:
                                    widget.scrollManager.clampingScrollPhysics,
                                controller: widget.horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: max(
                                    getMaxLineCount() * charWidth +
                                        charWidth +
                                        viewPadding,
                                    constraints.maxWidth,
                                  ),
                                  height: contentHeight,
                                  child: CustomPaint(
                                    key: _painterKey,
                                    painter: EditorPainter(
                                      currentLineIndex:
                                          keyboardHandler.caretLine,
                                      fontSize: widget.fontSize,
                                      fontFamily: widget.fontFamily,
                                      lineHeight: widget.lineHeight,
                                      viewportHeight:
                                          MediaQuery.of(context).size.height,
                                      viewportWidth:
                                          MediaQuery.of(context).size.width,
                                      verticalOffset: _verticalOffset,
                                      horizontalOffset: _horizontalOffset,
                                      lines: rope.text.split('\n'),
                                      caretPosition:
                                          keyboardHandler.caretPosition,
                                      caretLine: keyboardHandler.caretLine,
                                      selectionStart: widget
                                          .editorSelectionManager
                                          .selectionStart,
                                      selectionEnd: widget
                                          .editorSelectionManager.selectionEnd,
                                      lineStarts: rope.lineStarts,
                                      text: rope.text,
                                      lastUpdatedLine: _lastUpdatedLine,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _handleTap(TapDownDetails details) {
    int currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastClickTime < _doubleClickTime) {
      _clickCount++;
    } else {
      _clickCount = 1;
    }
    _lastClickTime = currentTime;

    setState(() {
      if (_clickCount == 1) {
        handleClick(details);
        widget.editorSelectionManager.setSelectionMode(SelectionMode.normal);
      } else if (_clickCount == 2) {
        handleDoubleClick(details);
        widget.editorSelectionManager.setSelectionMode(SelectionMode.word);
      } else if (_clickCount == 3) {
        handleTripleClick(details);
        widget.editorSelectionManager.setSelectionMode(SelectionMode.line);
        _clickCount = 0; // Reset after triple click
      }
    });
  }

  void handleClick(TapDownDetails details) {
    final tapPosition = getPositionFromOffset(details.localPosition);
    keyboardHandler.absoluteCaretPosition = tapPosition;
    keyboardHandler.updateCaretPosition();
    widget.editorSelectionManager.clearSelection();
  }

  void handleDoubleClick(TapDownDetails details) {
    final tapPosition = getPositionFromOffset(details.localPosition);
    int selectionStart, selectionEnd;

    int line = getLineFromOffset(details.localPosition);
    int lineStart = rope.findClosestLineStart(line);
    int lineEnd = (line < rope.lineCount - 1)
        ? rope.findClosestLineStart(line + 1) - 1
        : rope.length;

    // Check if the line is empty
    bool isEmptyLine = lineStart == lineEnd;

    if (isEmptyLine) {
      // If the line is empty, don't select anything
      selectionStart = selectionEnd = lineStart;
    } else if (tapPosition >= lineEnd) {
      // Clicked beyond the line's end, select the last word
      selectionEnd = lineEnd;
      selectionStart = findWordBoundary(lineEnd - 1, true);
    } else if (tapPosition >= rope.length) {
      selectionStart = selectionEnd = rope.length;
    } else if (isWhitespace(rope.charAt(tapPosition))) {
      selectionStart = findWhitespaceBoundary(tapPosition, true);
      selectionEnd = findWhitespaceBoundary(tapPosition, false);
    } else {
      selectionStart = findWordBoundary(tapPosition, true);
      selectionEnd = findWordBoundary(tapPosition, false);
    }

    setState(() {
      widget.editorSelectionManager.selectionAnchor = selectionStart;
      widget.editorSelectionManager.selectionFocus = selectionEnd;
      widget.editorSelectionManager.selectionStart = selectionStart;
      widget.editorSelectionManager.selectionEnd = selectionEnd;

      keyboardHandler.absoluteCaretPosition = selectionEnd;
      keyboardHandler.updateCaretPosition();
    });
  }

  void handleTripleClick(TapDownDetails details) {
    int lineNumber = getLineFromOffset(details.localPosition);
    int lineStart = rope.findClosestLineStart(lineNumber);
    int lineEnd = lineNumber < rope.lineCount - 1
        ? rope.findClosestLineStart(lineNumber + 1)
        : rope.length;

    setState(() {
      widget.editorSelectionManager.selectionAnchor = lineStart;
      widget.editorSelectionManager.selectionFocus = lineEnd;
      widget.editorSelectionManager.selectionStart = lineStart;
      widget.editorSelectionManager.selectionEnd = lineEnd;
      keyboardHandler.absoluteCaretPosition = lineEnd;
      keyboardHandler.updateCaretPosition();
    });
  }

  void handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      setState(() {
        Offset constrainedOffset = constrainOffset(details.localPosition);
        int currentPosition = getPositionFromOffset(constrainedOffset);
        currentPosition = currentPosition.clamp(0, rope.length);

        if (widget.editorSelectionManager.selectionMode == SelectionMode.word) {
          if (currentPosition > widget.editorSelectionManager.selectionAnchor) {
            // Moving right/down
            widget.editorSelectionManager.selectionFocus =
                findWordBoundary(currentPosition, false);
          } else {
            // Moving left/up
            widget.editorSelectionManager.selectionFocus =
                findWordBoundary(currentPosition, true);
          }
        } else if (widget.editorSelectionManager.selectionMode ==
            SelectionMode.line) {
          int anchorLine = getLineFromPosition(
              widget.editorSelectionManager.selectionAnchor);
          int currentLine = getLineFromPosition(currentPosition);

          if (currentLine < anchorLine) {
            widget.editorSelectionManager.selectionFocus =
                rope.findClosestLineStart(currentLine);
          } else {
            widget.editorSelectionManager.selectionFocus =
                currentLine < rope.lineCount - 1
                    ? rope.findClosestLineStart(currentLine + 1)
                    : rope.length;
          }
        } else {
          widget.editorSelectionManager.selectionFocus = currentPosition;
        }

        widget.editorSelectionManager.selectionFocus =
            widget.editorSelectionManager.selectionFocus.clamp(0, rope.length);

        keyboardHandler.absoluteCaretPosition =
            widget.editorSelectionManager.selectionFocus;
        keyboardHandler.updateCaretPosition();
        widget.editorSelectionManager.updateSelection();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureCursorVisible();
        });
      });
    }
  }

  void handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartPosition = getPositionFromOffset(details.localPosition);
      if (widget.editorSelectionManager.selectionMode == SelectionMode.word) {
        widget.editorSelectionManager.selectionAnchor =
            findWordBoundary(_dragStartPosition, true);
        widget.editorSelectionManager.selectionFocus =
            findWordBoundary(_dragStartPosition, false);
      } else if (widget.editorSelectionManager.selectionMode ==
          SelectionMode.line) {
        int lineNumber = getLineFromOffset(details.localPosition);
        widget.editorSelectionManager.selectionAnchor =
            rope.findClosestLineStart(lineNumber);
        widget.editorSelectionManager.selectionFocus =
            lineNumber < rope.lineCount - 1
                ? rope.findClosestLineStart(lineNumber + 1) - 1
                : rope.length;
      } else {
        widget.editorSelectionManager.selectionAnchor = _dragStartPosition;
        widget.editorSelectionManager.selectionFocus = _dragStartPosition;
      }
      keyboardHandler.absoluteCaretPosition =
          widget.editorSelectionManager.selectionFocus;
      keyboardHandler.updateCaretPosition();
      widget.editorSelectionManager.updateSelection();
    });
  }

  bool isBlankLine(int lineNumber) {
    int lineStart = rope.findClosestLineStart(lineNumber);
    int lineEnd = lineNumber < rope.lineCount - 1
        ? rope.findClosestLineStart(lineNumber + 1) - 1
        : rope.length;
    return lineStart == lineEnd;
  }

  int getLineFromPosition(int position) {
    return rope.findLineForPosition(position);
  }

  void handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      keyboardHandler.absoluteCaretPosition =
          widget.editorSelectionManager.selectionEnd;
      keyboardHandler.updateCaretPosition();
    });
  }

  bool isWhitespace(String char) {
    return char == ' ' || char == '\t' || char == '\n';
  }

  int findWhitespaceBoundary(int position, bool isStart) {
    position = position.clamp(0, rope.length);
    if (position == rope.length) return position;

    if (isStart) {
      while (position > 0 && isWhitespace(rope.charAt(position - 1))) {
        position--;
      }
    } else {
      while (position < rope.length && isWhitespace(rope.charAt(position))) {
        position++;
      }
    }

    return position;
  }

  int findWordBoundary(int position, bool isStart) {
    position = position.clamp(0, rope.length);
    if (position == rope.length) return position;

    bool isWordChar(String char) {
      return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
    }

    int lineStart =
        rope.findClosestLineStart(rope.findLineForPosition(position));
    int lineEnd =
        rope.findClosestLineStart(rope.findLineForPosition(position) + 1) - 1;

    if (isStart) {
      while (position > lineStart && !isWordChar(rope.charAt(position - 1))) {
        position--;
      }
      while (position > lineStart && isWordChar(rope.charAt(position - 1))) {
        position--;
      }
    } else {
      while (position < lineEnd && !isWordChar(rope.charAt(position))) {
        position++;
      }
      while (position < lineEnd && isWordChar(rope.charAt(position))) {
        position++;
      }
    }

    return position;
  }

  Offset constrainOffset(Offset offset) {
    double x = offset.dx.clamp(0, _editorSize.width);
    double y = (offset.dy + widget.verticalController.offset)
        .clamp(0, lineHeight * rope.lineCount);
    return Offset(x, y - widget.verticalController.offset);
  }

  int getLineFromOffset(Offset offset) {
    return min(
        (((offset.dy + widget.verticalController.offset) / lineHeight)).floor(),
        rope.lineCount - 1);
  }

  int getPositionFromOffset(Offset offset) {
    int line = min(
        (((offset.dy + widget.verticalController.offset) / lineHeight)).floor(),
        rope.lineCount - 1);
    int column =
        ((offset.dx + widget.horizontalController.offset) / charWidth).floor();
    return rope.findClosestLineStart(line) +
        min(column, rope.getLineLength(line));
  }

  int getMaxLineCount() {
    if (lineCounts.isNotEmpty) return lineCounts.reduce(max);
    return 0;
  }

  void updateLineCountsPartial(int startLine) {
    // Remove line counts for deleted lines
    if (startLine < lineCounts.length) {
      lineCounts = lineCounts.sublist(0, startLine);
    }

    // Update line counts from the start line to the end
    for (int i = startLine; i < rope.lineCount; i++) {
      if (i < lineCounts.length) {
        lineCounts[i] = rope.getLineLength(i);
      } else {
        lineCounts.add(rope.getLineLength(i));
      }
    }
  }

  void updateLineCounts() {
    lineCounts.clear();
    for (int i = 0; i < rope.lineCount; i++) {
      lineCounts.add(rope.getLineLength(i));
    }
    _painterKey = UniqueKey(); // Force painter to update
    _updateContentSize();
  }

  void _handleScroll() {
    int firstVisibleLine = (_verticalOffset / lineHeight).floor();
    if (firstVisibleLine < _lastUpdatedLine) {
      setState(() {
        updateLineCountsPartial(firstVisibleLine);
        _lastUpdatedLine = firstVisibleLine;
      });
    }
  }

  void saveFile() {
    if (widget.tabService.currentTabIndex == null) return;

    final currentTab =
        widget.tabService.tabs[widget.tabService.currentTabIndex!];
    try {
      File(currentTab.path).writeAsStringSync(rope.text);
      widget.tabService
          .updateTabContent(currentTab.path, rope.text, isModified: false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  Future<void> _ensureCursorVisible() async {
    await widget.scrollManager.ensureCursorVisible(
      widget.horizontalController,
      widget.verticalController,
      charWidth,
      keyboardHandler.caretPosition,
      lineHeight,
      keyboardHandler.caretLine,
      editorPadding,
      viewPadding,
      context,
    );
  }

  void updateAfterEdit(int startLine, int endLine) {
    updateLineCountsPartial(startLine);
    _painterKey = UniqueKey();
    widget.tab.content = rope.text;

    // Update the vertical offset to ensure newly visible lines are drawn
    double newVerticalOffset = max(0,
        widget.verticalController.offset - (endLine - startLine) * lineHeight);
    widget.verticalController.jumpTo(newVerticalOffset);

    setState(() {
      _verticalOffset = newVerticalOffset;
    });
  }
}

class EditorPainter extends CustomPainter {
  final List<String> lines;
  final int caretPosition;
  final int caretLine;
  final int selectionStart;
  final int selectionEnd;
  final List<int> lineStarts;
  final String text;
  late double charWidth;
  late double lineHeight;
  double horizontalOffset;
  double verticalOffset;
  double viewportHeight;
  double viewportWidth;
  final String fontFamily;
  final double fontSize;
  final int lastUpdatedLine;
  final int currentLineIndex;

  EditorPainter({
    required this.lines,
    required this.caretPosition,
    required this.caretLine,
    required this.selectionStart,
    required this.selectionEnd,
    required this.lineStarts,
    required this.text,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.viewportHeight,
    required this.viewportWidth,
    required this.lineHeight,
    required this.fontFamily,
    required this.fontSize,
    required this.lastUpdatedLine,
    required this.currentLineIndex,
  }) {
    charWidth = _measureCharWidth("w");
    lineHeight = _measureLineHeight("y");

    _EditorContentState.lineHeight = lineHeight;
    _EditorContentState.charWidth = charWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    int firstVisibleLine = max((verticalOffset / lineHeight).floor(), 0);
    int lastVisibleLine = min(
        firstVisibleLine + (viewportHeight / lineHeight).ceil(), lines.length);

    if (lines.isNotEmpty) {
      for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
        if (i < lines.length) {
          TextSpan span = TextSpan(
            text: lines[i],
            style: TextStyle(
              fontFamily: fontFamily,
              color: Colors.black,
              fontSize: fontSize,
              height: 1,
            ),
          );
          TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr,
          );
          tp.layout(maxWidth: size.width);

          double yPosition = (lineHeight * i) + ((lineHeight - tp.height) / 2);
          tp.paint(canvas, Offset(0, yPosition));
        }
      }
    }

    highlightCurrentLine(canvas, currentLineIndex, size);
    drawSelection(canvas, firstVisibleLine, lastVisibleLine);

    // Draw caret
    if (caretLine >= firstVisibleLine &&
        caretLine < lastVisibleLine &&
        caretLine < lines.length) {
      canvas.drawRect(
        Rect.fromLTWH(
          caretPosition * charWidth,
          lineHeight * caretLine,
          2,
          lineHeight,
        ),
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.caretPosition != caretPosition ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd ||
        oldDelegate.caretLine != caretLine ||
        oldDelegate.verticalOffset != verticalOffset ||
        oldDelegate.horizontalOffset != horizontalOffset ||
        oldDelegate.viewportHeight != viewportHeight ||
        oldDelegate.viewportWidth != viewportWidth ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.charWidth != charWidth ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.lastUpdatedLine != lastUpdatedLine ||
        oldDelegate.lineStarts != lineStarts ||
        oldDelegate.text != text;
  }

  double _measureCharWidth(String s) {
    final textSpan = TextSpan(
      text: s,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.white,
        fontFamily: fontFamily,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.width;
  }

  double _measureLineHeight(String s) {
    final textSpan = TextSpan(
      text: s,
      style: TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: Colors.white,
        fontFamily: fontFamily,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.height;
  }

  void drawSelection(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (selectionStart != selectionEnd && lines.isNotEmpty) {
      for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
        if (i >= lineStarts.length) {
          int lineStart =
              (i > 0 ? lineStarts[i - 1] + lines[i - 1].length : 0).toInt();
          int lineEnd = text.length;
          drawSelectionForLine(canvas, i, lineStart, lineEnd);
          continue;
        }

        int lineStart = lineStarts[i];
        int lineEnd =
            i < lineStarts.length - 1 ? lineStarts[i + 1] - 1 : text.length;

        // For empty lines that are not the last line, print a 1 char selection
        if (lineEnd - lineStart == 0) {
          lineEnd++;
        }

        drawSelectionForLine(canvas, i, lineStart, lineEnd);
      }
    }
  }

  void highlightCurrentLine(Canvas canvas, int currentLineIndex, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, lineHeight * currentLineIndex, size.width, lineHeight),
        Paint()
          ..color = Colors.grey.withOpacity(0.1)
          ..style = PaintingStyle.fill);
  }

  void drawSelectionForLine(
      Canvas canvas, int lineIndex, int lineStart, int lineEnd) {
    if (lineStart < selectionEnd && lineEnd > selectionStart) {
      double startX = (max(selectionStart, lineStart) - lineStart).toDouble();
      double endX = (min(selectionEnd, lineEnd) - lineStart).toDouble();

      canvas.drawRect(
        Rect.fromLTWH(
          startX * charWidth,
          lineHeight * lineIndex,
          (endX - startX) * charWidth,
          lineHeight,
        ),
        Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
    }
  }
}
