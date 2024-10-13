import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:starlight/features/context_menu/context_menu.dart';
import 'package:starlight/features/editor/editor_painter.dart';
import 'package:starlight/features/editor/gutter/gutter.dart';
import 'package:starlight/features/editor/minimap/minimap.dart';
import 'package:starlight/features/editor/models/direction.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/models/selection_mode.dart';
import 'package:starlight/features/editor/services/editor_keyboard_handler.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/features/editor/services/editor_selection_manager.dart';
import 'package:starlight/features/editor/services/syntax_highlighting_service.dart';
import 'package:starlight/services/caret_position_notifier.dart';
import 'package:starlight/services/config_service.dart';
import 'package:starlight/services/hotkey_service.dart';
import 'package:starlight/widgets/tab/tab.dart' as CustomTab;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';

class EditorContent extends StatefulWidget {
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final EditorScrollManager scrollManager;
  final EditorSelectionManager editorSelectionManager;
  final ConfigService configService;
  final HotkeyService hotkeyService;
  final CustomTab.Tab tab;
  final FileService fileService;
  final TabService tabService;
  final double lineHeight;
  final String fontFamily;
  final double fontSize;
  final int tabSize;
  final CaretPositionNotifier caretPositionNotifier;
  final bool showMinimap;
  final bool isSearchVisible;
  final String searchQuery;
  final List<int> matchPositions;
  final int currentMatch;
  final List<int> selectedMatches;
  final ValueNotifier<String> contentNotifier;
  final ValueNotifier<String> searchQueryNotifier;

  double get actualLineHeight => EditorContentState.lineHeight;
  double get charWidth => EditorContentState.charWidth;

  const EditorContent(
      {super.key,
      required this.contentNotifier,
      required this.configService,
      required this.editorSelectionManager,
      required this.hotkeyService,
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
      required this.caretPositionNotifier,
      this.showMinimap = true,
      required this.isSearchVisible,
      required this.searchQuery,
      required this.matchPositions,
      required this.currentMatch,
      required this.selectedMatches,
      required this.searchQueryNotifier});

  @override
  State<EditorContent> createState() => EditorContentState();
}

class EditorContentState extends State<EditorContent> {
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
  late Size _editorSize;
  int _clickCount = 0;
  int _lastClickTime = 0;
  static const int _doubleClickTime = 300; // milliseconds
  late EditorKeyboardHandler keyboardHandler;
  List<int>? _matchingBrackets;

  @override
  void initState() {
    super.initState();
    widget.contentNotifier.addListener(_onContentChanged);
    rope = Rope(widget.tab.content);
    updateLineCounts();

    widget.caretPositionNotifier.addListener(_handleCaretPositionChange);
    widget.editorSelectionManager.updateRope(rope);
    widget.scrollManager.preventOverscroll(widget.horizontalController,
        widget.verticalController, editorPadding, viewPadding);
    widget.verticalController.addListener(_handleVerticalScroll);
    widget.horizontalController.addListener(_handleHorizontalScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateContentSize());
    widget.searchQueryNotifier.addListener(_onSearchQueryChanged);

    keyboardHandler = EditorKeyboardHandler(
      updateCursorPosition: (line, column) {
        widget.caretPositionNotifier.updatePosition(line, column);
      },
      rope: rope,
      configService: widget.configService,
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

  void _onSearchQueryChanged() {
    setState(() {});
  }

  void _handleCaretPositionChange() {
    final newPosition = widget.caretPositionNotifier.position;
    setState(() {
      int validLine = newPosition.line.clamp(0, rope.lineCount - 1).toInt();
      int lineLength = rope.getLineLength(validLine);

      int validColumn = newPosition.column.clamp(0, lineLength);

      keyboardHandler.caretLine = validLine;
      keyboardHandler.caretPosition = validColumn;
      keyboardHandler.stickyColumn = validColumn;
      keyboardHandler.absoluteCaretPosition =
          rope.findClosestLineStart(validLine) + validColumn;

      if (validLine != newPosition.line || validColumn != newPosition.column) {
        widget.caretPositionNotifier.updatePosition(validLine, validColumn);
      }

      _ensureCursorVisible();
    });
  }

  @override
  void dispose() {
    widget.contentNotifier.removeListener(_onContentChanged);
    widget.caretPositionNotifier.removeListener(_handleCaretPositionChange);
    widget.verticalController.removeListener(_handleVerticalScroll);
    widget.horizontalController.removeListener(_handleHorizontalScroll);
    widget.searchQueryNotifier.removeListener(_onSearchQueryChanged);
    super.dispose();
  }

  void _onContentChanged() {
    setState(() {
      rope = Rope(widget.contentNotifier.value);
      updateLineCounts();
      widget.editorSelectionManager.updateRope(rope);
      keyboardHandler.rope = rope;
    });
  }

  void _handleVerticalScroll() {
    setState(() {
      _verticalOffset = widget.verticalController.offset;
    });
  }

  List<int>? findMatchingQuote(int position, String quoteChar) {
    int lineStart =
        rope.findClosestLineStart(rope.findLineForPosition(position));
    int lineEnd =
        rope.findClosestLineStart(rope.findLineForPosition(position) + 1) - 1;

    List<int> quotePositions = [];
    String otherQuoteChar = quoteChar == "'" ? '"' : "'";
    bool inOtherQuote = false;

    for (int i = lineStart; i <= lineEnd; i++) {
      String currentChar = rope.charAt(i);

      if (currentChar == otherQuoteChar &&
          (i == lineStart || rope.charAt(i - 1) != '\\')) {
        inOtherQuote = !inOtherQuote;
      }

      if (!inOtherQuote &&
          currentChar == quoteChar &&
          (i == lineStart || rope.charAt(i - 1) != '\\')) {
        quotePositions.add(i);
      }
    }

    if (quotePositions.length < 2) {
      return null;
    }

    for (int i = 0; i < quotePositions.length; i += 2) {
      if (position >= quotePositions[i] && position <= quotePositions[i + 1]) {
        return [quotePositions[i], quotePositions[i + 1]];
      }
    }

    return null;
  }

  List<int>? findMatchingBracket(int position) {
    final brackets = {
      '(': ')',
      '[': ']',
      '{': '}',
      ')': '(',
      ']': '[',
      '}': '{',
      "'": "'",
      '"': '"'
    };
    final openBrackets = ['(', '[', '{'];

    // Check the character at the current position
    if (position < rope.length) {
      String currentChar = rope.charAt(position);
      if (brackets.containsKey(currentChar)) {
        if (currentChar == "'" || currentChar == '"') {
          return findMatchingQuote(position, currentChar);
        }
        return findMatchingBracketHelper(
            position, currentChar, brackets, openBrackets);
      }
    }

    // Check the character before the current position
    if (position > 0) {
      String prevChar = rope.charAt(position - 1);
      if (brackets.containsKey(prevChar)) {
        if (prevChar == "'" || prevChar == '"') {
          return findMatchingQuote(position - 1, prevChar);
        }
        return findMatchingBracketHelper(
            position - 1, prevChar, brackets, openBrackets);
      }
    }

    return null;
  }

  void updateContent(String newContent) {
    setState(() {
      rope = Rope(newContent);
      updateLineCounts();
      widget.editorSelectionManager.updateRope(rope);
      keyboardHandler.rope = rope;
    });
  }

  List<int>? findMatchingBracketHelper(int position, String currentChar,
      Map<String, String> brackets, List<String> openBrackets) {
    bool isOpenBracket = openBrackets.contains(currentChar);
    int direction = isOpenBracket ? 1 : -1;
    int matchPosition = position + direction;
    int nestingLevel = 1;

    while (matchPosition >= 0 && matchPosition < rope.length) {
      String char = rope.charAt(matchPosition);
      if (char == currentChar) {
        nestingLevel++;
      } else if (char == brackets[currentChar]) {
        nestingLevel--;
        if (nestingLevel == 0) {
          return [position, matchPosition];
        }
      }
      matchPosition += direction;
    }

    return null;
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
          _editorSize = context.size ?? Size.zero;
          widget.verticalController.jumpTo(widget.verticalController.offset);
          widget.horizontalController
              .jumpTo(widget.horizontalController.offset);
        },
      );
    });
  }

  void _cut() {
    keyboardHandler.cutText();
  }

  void _copy() {
    keyboardHandler.copyText();
  }

  void _paste() async {
    keyboardHandler.pasteText();
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset shiftedPosition = details.globalPosition.translate(0, 0);

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(shiftedPosition, shiftedPosition),
      Offset.zero & overlay.size,
    );

    final tapPosition = getPositionFromOffset(details.localPosition);

    if (!isPositionInSelection(tapPosition)) {
      setState(() {
        keyboardHandler.absoluteCaretPosition = tapPosition;
        keyboardHandler.updateAndNotifyCursorPosition();
        widget.editorSelectionManager.clearSelection();
      });
    }

    final List<ContextMenuItem> menuItems = [
      ContextMenuItem(label: 'Cut', onTap: _cut),
      ContextMenuItem(label: 'Copy', onTap: _copy),
      ContextMenuItem(label: 'Paste', onTap: _paste),
    ];

    showCommonContextMenu(
      context: context,
      position: position,
      items: menuItems,
    );
  }

  bool isPositionInSelection(int position) {
    return position >= widget.editorSelectionManager.selectionStart &&
        position < widget.editorSelectionManager.selectionEnd;
  }

  @override
  Widget build(BuildContext context) {
    final contentHeight = max(
          (lineHeight * rope.lineCount) + viewPadding,
          MediaQuery.of(context).size.height - 35,
        ) -
        92;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final editorWidth =
                  constraints.maxWidth - (widget.showMinimap ? 100 : 0);
              return Stack(
                children: [
                  SizedBox(
                    width: editorWidth,
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
                        onSecondaryTapUp: (TapUpDetails details) {
                          f.requestFocus();
                          _showContextMenu(context, details);
                        },
                        onLongPressStart: (LongPressStartDetails details) {
                          f.requestFocus();
                          handleDragStart(details.localPosition);
                        },
                        onLongPressMoveUpdate:
                            (LongPressMoveUpdateDetails details) {
                          f.requestFocus();
                          handleDragUpdate(details.localPosition);
                        },
                        onLongPressEnd: (LongPressEndDetails details) {
                          f.requestFocus();
                          handleDragEnd();
                        },
                        onPanStart: (DragStartDetails details) {
                          f.requestFocus();
                          handleDragStart(details.localPosition);
                        },
                        onPanUpdate: (DragUpdateDetails details) {
                          f.requestFocus();
                          handleDragUpdate(details.localPosition);
                        },
                        onPanEnd: (DragEndDetails details) {
                          f.requestFocus();
                          handleDragEnd();
                        },
                        behavior: HitTestBehavior.translucent,
                        child: Focus(
                          focusNode: f,
                          onKeyEvent: (node, event) {
                            var result = keyboardHandler.handleInput(event);
                            setState(() {
                              _lastUpdatedLine =
                                  keyboardHandler.lastUpdatedLine;
                              _matchingBrackets = findMatchingBracket(
                                  keyboardHandler.absoluteCaretPosition);
                            });
                            return result;
                          },
                          child: RawScrollbar(
                            controller: widget.verticalController,
                            thumbVisibility: false,
                            thickness: 8,
                            radius: Radius.zero,
                            thumbColor: Colors.grey.withOpacity(0.5),
                            fadeDuration: const Duration(milliseconds: 300),
                            timeToFade: const Duration(milliseconds: 1000),
                            child: RawScrollbar(
                              controller: widget.horizontalController,
                              thumbVisibility: false,
                              thickness: 8,
                              radius: Radius.zero,
                              thumbColor: Colors.grey.withOpacity(0.5),
                              fadeDuration: const Duration(milliseconds: 300),
                              timeToFade: const Duration(milliseconds: 1000),
                              notificationPredicate: (notification) =>
                                  notification.depth == 1,
                              child: ScrollConfiguration(
                                behavior: const ScrollBehavior()
                                    .copyWith(scrollbars: false),
                                child: SingleChildScrollView(
                                  physics: widget
                                      .scrollManager.clampingScrollPhysics,
                                  controller: widget.verticalController,
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    physics: widget
                                        .scrollManager.clampingScrollPhysics,
                                    controller: widget.horizontalController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: max(
                                        getMaxLineCount() * charWidth +
                                            charWidth +
                                            viewPadding,
                                        editorWidth,
                                      ),
                                      height: contentHeight,
                                      child: CustomPaint(
                                        key: _painterKey,
                                        painter: EditorPainter(
                                          selectedMatches:
                                              widget.selectedMatches,
                                          syntaxHighlighter:
                                              SyntaxHighlightingService(),
                                          isDragging: _isDragging,
                                          rope: rope,
                                          buildContext: context,
                                          currentLineIndex:
                                              keyboardHandler.caretLine,
                                          fontSize: widget.fontSize,
                                          fontFamily: widget.fontFamily,
                                          lineHeight: widget.lineHeight,
                                          viewportHeight: MediaQuery.of(context)
                                              .size
                                              .height,
                                          viewportWidth: editorWidth,
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
                                              .editorSelectionManager
                                              .selectionEnd,
                                          lineStarts: rope.lineStarts,
                                          text: rope.text,
                                          lastUpdatedLine: _lastUpdatedLine,
                                          matchingBrackets: _matchingBrackets,
                                          isSearchVisible:
                                              widget.isSearchVisible,
                                          searchQuery: widget.searchQuery,
                                          matchPositions: widget.matchPositions,
                                          currentMatch: widget.currentMatch,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.showMinimap)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: 100,
                        child: EditorMinimap(
                          syntaxHighlighter: SyntaxHighlightingService(),
                          rope: rope,
                          verticalController: widget.verticalController,
                          editorHeight: contentHeight,
                          lineHeight: lineHeight,
                          currentLine: keyboardHandler.caretLine,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
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

    final tapPosition = getPositionFromOffset(details.localPosition);

    setState(() {
      if (_clickCount == 1) {
        widget.editorSelectionManager.setSelectionMode(SelectionMode.normal);
        handleClick(tapPosition);
      } else if (_clickCount == 2) {
        widget.editorSelectionManager.setSelectionMode(SelectionMode.word);
        handleDoubleClick(tapPosition);
      } else if (_clickCount == 3) {
        widget.editorSelectionManager.setSelectionMode(SelectionMode.line);
        handleTripleClick(tapPosition);
        _clickCount = 0; // Reset after triple click
      }

      // Update matching brackets after changing the caret position
      _matchingBrackets =
          findMatchingBracket(keyboardHandler.absoluteCaretPosition);
    });
  }

  void handleClick(int position) {
    keyboardHandler.absoluteCaretPosition = position;
    keyboardHandler.updateAndNotifyCursorPosition();
    widget.caretPositionNotifier.updatePosition(
        keyboardHandler.caretLine, keyboardHandler.caretPosition);
    widget.editorSelectionManager.clearSelection();
    _matchingBrackets =
        findMatchingBracket(keyboardHandler.absoluteCaretPosition);
  }

  void handleDoubleClick(int position) {
    int selectionStart = findWordBoundary(position, true);
    int selectionEnd = findWordBoundary(position, false);

    widget.editorSelectionManager.selectionAnchor = selectionStart;
    widget.editorSelectionManager.selectionFocus = selectionEnd;
    widget.editorSelectionManager.updateSelection();

    keyboardHandler.absoluteCaretPosition = selectionEnd;
    keyboardHandler.updateAndNotifyCursorPosition();
    widget.caretPositionNotifier.updatePosition(
        keyboardHandler.caretLine, keyboardHandler.caretPosition);
    _matchingBrackets =
        findMatchingBracket(keyboardHandler.absoluteCaretPosition);
  }

  void handleTripleClick(int position) {
    int lineNumber = rope.findLineForPosition(position);
    int lineStart = rope.findClosestLineStart(lineNumber);
    int lineEnd = lineNumber < rope.lineCount - 1
        ? rope.findClosestLineStart(lineNumber + 1)
        : rope.length;

    widget.editorSelectionManager.selectionAnchor = lineStart;
    widget.editorSelectionManager.selectionFocus = lineEnd;
    widget.editorSelectionManager.updateSelection();

    keyboardHandler.absoluteCaretPosition = lineEnd;
    keyboardHandler.updateAndNotifyCursorPosition();
    widget.caretPositionNotifier.updatePosition(
        keyboardHandler.caretLine, keyboardHandler.caretPosition);
    _matchingBrackets =
        findMatchingBracket(keyboardHandler.absoluteCaretPosition);
  }

  void handleDragStart(Offset localPosition) {
    setState(() {
      _isDragging = true;
      int dragStartPosition = getPositionFromOffset(localPosition);

      widget.editorSelectionManager.selectionAnchor = dragStartPosition;
      widget.editorSelectionManager.selectionFocus = dragStartPosition;
      widget.editorSelectionManager.updateSelection();

      keyboardHandler.absoluteCaretPosition = dragStartPosition;
      keyboardHandler.updateAndNotifyCursorPosition();
      widget.caretPositionNotifier.updatePosition(
          keyboardHandler.caretLine, keyboardHandler.caretPosition);
      _matchingBrackets =
          findMatchingBracket(keyboardHandler.absoluteCaretPosition);
    });
  }

  void handleDragUpdate(Offset localPosition) {
    if (_isDragging) {
      setState(() {
        Offset constrainedOffset = constrainOffset(localPosition);
        int currentPosition = getPositionFromOffset(constrainedOffset);
        currentPosition = currentPosition.clamp(0, rope.length);

        switch (widget.editorSelectionManager.selectionMode) {
          case SelectionMode.word:
            if (currentPosition >
                widget.editorSelectionManager.selectionAnchor) {
              widget.editorSelectionManager.selectionFocus =
                  findWordBoundary(currentPosition, false);
            } else {
              widget.editorSelectionManager.selectionFocus =
                  findWordBoundary(currentPosition, true);
            }
            break;
          case SelectionMode.line:
            int anchorLine = rope.findLineForPosition(
                widget.editorSelectionManager.selectionAnchor);
            int currentLine = rope.findLineForPosition(currentPosition);

            if (currentLine < anchorLine) {
              widget.editorSelectionManager.selectionFocus =
                  rope.findClosestLineStart(currentLine);
            } else {
              widget.editorSelectionManager.selectionFocus =
                  currentLine < rope.lineCount - 1
                      ? rope.findClosestLineStart(currentLine + 1)
                      : rope.length;
            }
            break;
          default:
            widget.editorSelectionManager.selectionFocus = currentPosition;
        }

        widget.editorSelectionManager.updateSelection();
        keyboardHandler.absoluteCaretPosition =
            widget.editorSelectionManager.selectionFocus;
        keyboardHandler.updateAndNotifyCursorPosition();
        widget.caretPositionNotifier.updatePosition(
            keyboardHandler.caretLine, keyboardHandler.caretPosition);
        _matchingBrackets =
            findMatchingBracket(keyboardHandler.absoluteCaretPosition);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureCursorVisible();
        });
      });
    }
  }

  void handleDragEnd() {
    setState(() {
      _isDragging = false;
      keyboardHandler.absoluteCaretPosition =
          widget.editorSelectionManager.selectionEnd;
      keyboardHandler.updateAndNotifyCursorPosition();
      widget.caretPositionNotifier.updatePosition(
          keyboardHandler.caretLine, keyboardHandler.caretPosition);
      _matchingBrackets =
          findMatchingBracket(keyboardHandler.absoluteCaretPosition);
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
    if (widget.tabService.currentTabIndexNotifier.value == null) return;

    final currentTab = widget
        .tabService.tabs[widget.tabService.currentTabIndexNotifier.value!];
    try {
      File(currentTab.fullPath).writeAsStringSync(rope.text);
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
