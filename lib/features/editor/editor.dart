import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide VerticalDirection;
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/gutter/gutter.dart';
import 'package:starlight/features/editor/models/direction.dart';
import 'package:starlight/features/editor/models/rope.dart';
import 'package:starlight/features/editor/services/editor_scroll_manager.dart';
import 'package:starlight/models/tab.dart' as CustomTab;
import 'package:starlight/services/file_service.dart';
import 'package:starlight/services/tab_service.dart';

class Editor extends StatefulWidget {
  final TabService tabService;
  final FileService fileService;

  const Editor(
      {super.key, required this.tabService, required this.fileService});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with TickerProviderStateMixin {
  final EditorScrollManager _scrollManager = EditorScrollManager();
  late List<ScrollController> _verticalControllers;
  late List<ScrollController> _horizontalControllers;
  List<Widget> _editorInstances = [];
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    _initScrollControllers();
    tabController = TabController(
        length: widget.tabService.tabs.length,
        vsync: this,
        animationDuration: Duration.zero);
    _updateEditorInstances();
    widget.tabService.addListener(_handleTabsChanged);
  }

  void _initScrollControllers() {
    _verticalControllers = List.generate(
      widget.tabService.tabs.length,
      (_) => ScrollController(),
    );
    _horizontalControllers = List.generate(
      widget.tabService.tabs.length,
      (_) => ScrollController(),
    );
  }

  void _handleTabsChanged() {
    setState(() {
      _disposeScrollControllers();
      _initScrollControllers();
      tabController.dispose();
      tabController = TabController(
          length: widget.tabService.tabs.length,
          vsync: this,
          animationDuration: Duration.zero);
      _updateEditorInstances();
    });
  }

  void _updateEditorInstances() {
    _editorInstances = List.generate(
      widget.tabService.tabs.length,
      (index) => _buildEditor(index),
    );
  }

  void _disposeScrollControllers() {
    for (var controller in _verticalControllers) {
      controller.dispose();
    }
    for (var controller in _horizontalControllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _disposeScrollControllers();
    tabController.dispose();
    widget.tabService.removeListener(_handleTabsChanged);
    super.dispose();
  }

  Widget _buildEditor(int index) {
    return EditorContent(
      verticalController: _verticalControllers[index],
      horizontalController: _horizontalControllers[index],
      scrollManager: _scrollManager,
      tab: widget.tabService.tabs[index],
      fileService: widget.fileService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: TabBar(
              splashFactory: NoSplash.splashFactory,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              controller: tabController,
              isScrollable: true,
              tabs: widget.tabService.tabs
                  .map((CustomTab.Tab tab) =>
                      Tab(text: tab.path.split('/').last))
                  .toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: tabController,
              children: _editorInstances,
            ),
          ),
        ],
      ),
    );
  }
}

class EditorContent extends StatefulWidget {
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final EditorScrollManager scrollManager;
  final CustomTab.Tab tab;
  final FileService fileService;

  const EditorContent({
    super.key,
    required this.verticalController,
    required this.horizontalController,
    required this.scrollManager,
    required this.tab,
    required this.fileService,
  });

  @override
  State<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends State<EditorContent> {
  final FocusNode f = FocusNode();
  late Rope rope;
  int absoluteCaretPosition = 0;
  int caretPosition = 0;
  int caretLine = 0;
  static double lineHeight = 0;
  static double charWidth = 0;
  List<int> lineCounts = [0];
  double viewPadding = 100;
  double editorPadding = 5;
  HorizontalDirection horizontalDirection = HorizontalDirection.right;
  VerticalDirection verticalDirection = VerticalDirection.down;
  int selectionStart = -1;
  int selectionEnd = -1;
  int selectionAnchor = -1;
  int selectionFocus = -1;

  @override
  void initState() {
    super.initState();
    rope = Rope(widget.tab.content);
    updateLineCounts();
    widget.scrollManager.preventOverscroll(widget.horizontalController,
        widget.verticalController, editorPadding, viewPadding);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EditorGutter(
          height: max(
            (lineHeight * rope.lineCount) - editorPadding + viewPadding,
            MediaQuery.of(context).size.height,
          ),
          editorVerticalScrollController: widget.verticalController,
          lineCount: rope.lineCount,
          editorPadding: editorPadding,
        ),
        Expanded(
          child: GestureDetector(
            onTapDown: (TapDownDetails details) => f.requestFocus(),
            behavior: HitTestBehavior.translucent,
            child: Focus(
              focusNode: f,
              onKeyEvent: (node, event) => handleInput(event),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RawScrollbar(
                          controller: widget.verticalController,
                          thumbVisibility: true,
                          thickness: 8,
                          radius: const Radius.circular(4),
                          thumbColor: Colors.grey.withOpacity(0.5),
                          minThumbLength: 30,
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
                                  height: max(
                                    (lineHeight * rope.lineCount) +
                                        viewPadding -
                                        editorPadding,
                                    constraints.maxHeight,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        editorPadding, editorPadding, 0, 0),
                                    child: CustomPaint(
                                      painter: EditorPainter(
                                        lines: rope.text.split('\n'),
                                        caretPosition: caretPosition,
                                        caretLine: caretLine,
                                        selectionStart: selectionStart,
                                        selectionEnd: selectionEnd,
                                        lineStarts: rope.lineStarts,
                                        text: rope.text,
                                      ),
                                    ),
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
      ],
    );
  }

  int getMaxLineCount() {
    if (lineCounts.isNotEmpty) return lineCounts.reduce(max);
    return 0;
  }

  void updateLineCounts() {
    lineCounts.clear();
    for (int i = 0; i < rope.lineCount; i++) {
      lineCounts.add(rope.getLineLength(i));
    }
  }

  KeyEventResult handleInput(KeyEvent keyEvent) {
    bool isKeyDownEvent = keyEvent is KeyDownEvent;
    bool isKeyRepeatEvent = keyEvent is KeyRepeatEvent;
    bool isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    bool isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if ((isCtrlPressed && !Platform.isMacOS) ||
        (Platform.isMacOS && isMetaPressed) && keyEvent.character != null) {
      _handleCtrlKeys(keyEvent.character!);
      return KeyEventResult.handled;
    }

    if ((isKeyDownEvent || isKeyRepeatEvent) &&
        keyEvent.character != null &&
        keyEvent.logicalKey != LogicalKeyboardKey.backspace &&
        keyEvent.logicalKey != LogicalKeyboardKey.enter) {
      setState(() {
        if (selectionStart != selectionEnd) {
          deleteSelection();
        }

        rope.insert(keyEvent.character!, absoluteCaretPosition);
        caretPosition++;
        absoluteCaretPosition++;

        updateLineCounts();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _ensureCursorVisible();
        });
      });
      return KeyEventResult.handled;
    } else {
      if ((isKeyDownEvent || isKeyRepeatEvent)) {
        setState(() {
          switch (keyEvent.logicalKey) {
            case LogicalKeyboardKey.backspace:
              handleBackspaceKey();
              horizontalDirection = HorizontalDirection.left;
              verticalDirection = VerticalDirection.up;
              break;
            case LogicalKeyboardKey.enter:
              handleEnterKey();
              verticalDirection = VerticalDirection.down;
              break;
            case LogicalKeyboardKey.arrowLeft:
              handleArrowKeys(LogicalKeyboardKey.arrowLeft, isShiftPressed);
              horizontalDirection = HorizontalDirection.left;
              break;
            case LogicalKeyboardKey.arrowRight:
              handleArrowKeys(LogicalKeyboardKey.arrowRight, isShiftPressed);
              horizontalDirection = HorizontalDirection.right;
              break;
            case LogicalKeyboardKey.arrowUp:
              handleArrowKeys(LogicalKeyboardKey.arrowUp, isShiftPressed);
              verticalDirection = VerticalDirection.up;
              break;
            case LogicalKeyboardKey.arrowDown:
              handleArrowKeys(LogicalKeyboardKey.arrowDown, isShiftPressed);
              verticalDirection = VerticalDirection.down;
              break;
          }

          updateLineCounts();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _ensureCursorVisible();
          });
        });
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }
  }

  void _handleCtrlKeys(String key) {
    switch (key) {
      case 'a':
        setState(() {
          selectionAnchor = 0;
          selectionFocus = rope.length;
          updateSelection();
          int lastLineLength = rope.getLineLength(rope.lineCount - 1);
          caretPosition = lastLineLength;
          absoluteCaretPosition = rope.length;
          caretLine = rope.lineCount - 1;
        });
        break;
      case 'v':
        pasteText();
        break;
      case 'c':
        copyText();
        break;
      case 'x':
        cutText();
        break;
    }
  }

  Future<void> pasteText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final textToBePasted = clipboardData?.text;

    if (textToBePasted == null || textToBePasted.isEmpty) {
      return;
    }

    setState(() {
      if (hasSelection()) {
        deleteSelection();
      }

      rope.insert(textToBePasted, absoluteCaretPosition);
      absoluteCaretPosition += textToBePasted.length;
      int line = rope.findLineForPosition(absoluteCaretPosition);
      int caretAdjustment =
          absoluteCaretPosition - rope.findClosestLineStart(line);

      caretLine = line;
      caretPosition = caretAdjustment;

      selectionStart = selectionEnd = absoluteCaretPosition;

      updateLineCounts();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureCursorVisible();
    });
  }

  Future<void> _ensureCursorVisible() async {
    await widget.scrollManager.ensureCursorVisible(
      widget.horizontalController,
      widget.verticalController,
      charWidth,
      caretPosition,
      lineHeight,
      caretLine,
      editorPadding,
      viewPadding,
      context,
    );
  }

  void copyText() {
    if (hasSelection()) {
      Clipboard.setData(ClipboardData(
        text: rope.text.substring(selectionStart, selectionEnd),
      ));
    } else {
      int closestLineStart = rope.findClosestLineStart(caretLine);
      int lineEnd = rope.getLineLength(caretLine) + closestLineStart;
      Clipboard.setData(ClipboardData(
        text: rope.text.substring(closestLineStart, lineEnd),
      ));
    }
  }

  void cutText() {
    copyText();
    deleteSelection();
  }

  void handleArrowKeys(LogicalKeyboardKey key, bool isShiftPressed) {
    int oldCaretPosition = absoluteCaretPosition;

    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        moveCaretVertically(1);
        break;
      case LogicalKeyboardKey.arrowUp:
        moveCaretVertically(-1);
        break;
      case LogicalKeyboardKey.arrowLeft:
        moveCaretHorizontally(-1);
        break;
      case LogicalKeyboardKey.arrowRight:
        moveCaretHorizontally(1);
        break;
    }

    if (isShiftPressed) {
      if (selectionAnchor == -1) {
        selectionAnchor = oldCaretPosition;
      }
      selectionFocus = absoluteCaretPosition;
    } else {
      clearSelection();
    }

    updateSelection();
  }

  void clearSelection() {
    selectionAnchor = -1;
    selectionFocus = -1;
    selectionStart = -1;
    selectionEnd = -1;
  }

  void updateSelection() {
    if (selectionAnchor != -1 && selectionFocus != -1) {
      selectionStart = min(selectionAnchor, selectionFocus);
      selectionEnd = max(selectionAnchor, selectionFocus);
    } else {
      selectionStart = selectionEnd = -1;
    }
  }

  void handleBackspaceKey() {
    if (hasSelection()) {
      deleteSelection();
    } else if (absoluteCaretPosition > 0) {
      if (caretPosition == 0 && caretLine > 0) {
        caretLine--;
        caretPosition = rope.getLineLength(caretLine);
        rope.delete(absoluteCaretPosition - 1, 1); // Delete the newline
        absoluteCaretPosition--;
      } else if (caretPosition > 0) {
        rope.delete(absoluteCaretPosition - 1, 1);
        caretPosition--;
        absoluteCaretPosition--;
      }
      caretLine = max(0, caretLine);
      caretPosition = max(0, min(caretPosition, rope.getLineLength(caretLine)));
      absoluteCaretPosition = max(0, min(absoluteCaretPosition, rope.length));
    }
  }

  void handleEnterKey() {
    rope.insert('\n', absoluteCaretPosition);
    caretLine++;
    caretPosition = 0;
    absoluteCaretPosition++;
  }

  void moveCaretHorizontally(int amount) {
    int newCaretPosition = caretPosition + amount;
    int currentLineLength = rope.getLineLength(caretLine);

    if (newCaretPosition >= 0 && newCaretPosition <= currentLineLength) {
      caretPosition = newCaretPosition;
      absoluteCaretPosition += amount;
    } else if (newCaretPosition < 0 && caretLine > 0) {
      caretLine--;
      caretPosition = rope.getLineLength(caretLine);
      absoluteCaretPosition =
          rope.findClosestLineStart(caretLine) + caretPosition;
    } else if (newCaretPosition > currentLineLength &&
        caretLine < rope.lineCount - 1) {
      caretLine++;
      caretPosition = 0;
      absoluteCaretPosition = rope.findClosestLineStart(caretLine);
    }

    if (caretLine == rope.lineCount - 1) {
      absoluteCaretPosition = max(0, min(absoluteCaretPosition, rope.length));
    } else {
      absoluteCaretPosition =
          max(0, min(absoluteCaretPosition, rope.length - 1));
    }
    moveSelectionHorizontally(absoluteCaretPosition);
  }

  void moveCaretVertically(int amount) {
    int targetLine = caretLine + amount;
    if (targetLine >= 0 && targetLine < rope.lineCount) {
      int targetLineStart = rope.findClosestLineStart(targetLine);
      int targetLineLength = rope.getLineLength(targetLine);

      if (targetLineLength <= 1) {
        caretPosition = 0;
      } else if (targetLine == rope.lineCount - 1) {
        caretPosition = min(caretPosition, targetLineLength);
      } else {
        // Skip the newline
        caretPosition = min(caretPosition, targetLineLength - 1);
      }

      caretLine = targetLine;
      absoluteCaretPosition = targetLineStart + caretPosition;
      moveSelectionVertically(absoluteCaretPosition);
    }
  }

  bool hasSelection() {
    return selectionStart != -1 &&
        selectionEnd != -1 &&
        selectionStart != selectionEnd;
  }

  void deleteSelection() {
    if (hasSelection()) {
      int start = min(selectionStart, selectionEnd);
      int end = max(selectionStart, selectionEnd);
      int length = end - start;

      rope.delete(start, length);
      absoluteCaretPosition = start;
      updateCaretPosition();
      clearSelection();
    }
  }

  void updateCaretPosition() {
    caretLine = rope.findLineForPosition(absoluteCaretPosition);
    int lineStart = rope.findClosestLineStart(caretLine);
    caretPosition = absoluteCaretPosition - lineStart;
  }

  void moveSelectionHorizontally(int target) {
    if (target > 0) {
      selectionEnd = target;
      if (selectionStart == -1) {
        selectionStart = target;
      }
    } else {
      selectionStart = target;
    }
    normalizeSelection();
  }

  void moveSelectionVertically(int target) {
    if (target > 0) {
      selectionEnd = target;
    } else {
      selectionStart = target;
    }
    normalizeSelection();
  }

  void normalizeSelection() {
    if (selectionStart > selectionEnd) {
      int temp = selectionStart;
      selectionStart = selectionEnd;
      selectionEnd = temp;
    }
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

  EditorPainter({
    required this.lines,
    required this.caretPosition,
    required this.caretLine,
    required this.selectionStart,
    required this.selectionEnd,
    required this.lineStarts,
    required this.text,
  }) {
    charWidth = _measureCharWidth("w");
    lineHeight = _measureLineHeight("y");

    _EditorContentState.lineHeight = lineHeight;
    _EditorContentState.charWidth = charWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < lines.length; i++) {
      TextSpan span = TextSpan(
        text: lines[i],
        style: const TextStyle(
          fontFamily: "Spot Mono",
          color: Colors.black,
          fontSize: 14,
        ),
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: size.width);

      tp.paint(canvas, Offset(0, lineHeight * i));
    }

    drawSelection(canvas);

    canvas.drawRect(
      Rect.fromLTWH(
        caretPosition.toDouble() * charWidth,
        lineHeight * (caretLine + 1) - lineHeight,
        2,
        lineHeight,
      ),
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.caretPosition != caretPosition ||
        oldDelegate.selectionStart != selectionStart ||
        oldDelegate.selectionEnd != selectionEnd ||
        oldDelegate.caretLine != caretLine;
  }

  double _measureCharWidth(String s) {
    final textSpan = TextSpan(
      text: s,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontFamily: "Spot Mono",
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.width;
  }

  double _measureLineHeight(String s) {
    final textSpan = TextSpan(
      text: s,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.white,
        fontFamily: "Spot Mono",
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    return tp.height;
  }

  void drawSelection(Canvas canvas) {
    if (selectionStart != selectionEnd && lines.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
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
