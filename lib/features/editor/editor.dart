import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';
import 'editor_painter.dart';
import 'line_numbers.dart';

class CodeEditor extends StatefulWidget {
  final String initialCode;

  const CodeEditor({super.key, required this.initialCode});

  @override
  _CodeEditorState createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late TextEditingCore editingCore;
  late ScrollController verticalController;
  late ScrollController horizontalController;
  late ScrollController lineNumberController;
  final FocusNode focusNode = FocusNode();

  bool _isVerticalScrolling = false;
  bool _isLineNumberScrolling = false;

  int firstVisibleLine = 0;
  int visibleLineCount = 0;
  double maxLineWidth = 0.0;
  double lineNumberWidth = 0.0;
  Map<int, double> lineWidthCache = {};

  static const double lineHeight = 24.0;
  static const double fontSize = 14.0;
  static const double lineWidthBuffer = 50.0;
  static late double charWidth;
  static const double scrollbarWidth = 12.0;

  @override
  void initState() {
    super.initState();
    editingCore = TextEditingCore(widget.initialCode);
    editingCore.addListener(_onTextChanged);
    verticalController = ScrollController()
      ..addListener(() => _syncScroll(isVertical: true));
    lineNumberController = ScrollController()
      ..addListener(() => _syncScroll(isVertical: false));
    horizontalController = ScrollController();

    _initializeCharWidth();
    _calculateLineNumberWidth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
    });
  }

  void _initializeCharWidth() {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(fontSize: fontSize, fontFamily: 'Courier'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    charWidth = textPainter.width;
  }

  void _calculateLineNumberWidth() {
    final lineCount = editingCore.lineCount;
    final maxLineNumberWidth = '$lineCount'.length * charWidth;
    lineNumberWidth = maxLineNumberWidth + 40;
  }

  void _syncScroll({required bool isVertical}) {
    if (isVertical && !_isLineNumberScrolling) {
      _isVerticalScrolling = true;
      lineNumberController.jumpTo(verticalController.offset);
      _isVerticalScrolling = false;
    } else if (!isVertical && !_isVerticalScrolling) {
      _isLineNumberScrolling = true;
      verticalController.jumpTo(lineNumberController.offset);
      _isLineNumberScrolling = false;
    }
    _updateVisibleLines();
  }

  void _updateVisibleLines() {
    if (!mounted || !verticalController.hasClients) return;
    setState(() {
      firstVisibleLine = (verticalController.offset / lineHeight).floor();
      visibleLineCount =
          (MediaQuery.of(context).size.height / lineHeight).ceil() + 1;
    });
  }

  void _onTextChanged() {
    _calculateLineNumberWidth();
    _calculateMaxLineWidth();
    setState(() {});
  }

  void _calculateMaxLineWidth() {
    double newMaxLineWidth = lineNumberWidth;
    int currentLineCount = editingCore.lineCount;

    for (int i = 0; i < currentLineCount; i++) {
      if (!lineWidthCache.containsKey(i)) {
        String line = editingCore.getLineContent(i);
        double lineWidth = line.length * charWidth + lineNumberWidth;
        lineWidthCache[i] = lineWidth;
      }
      newMaxLineWidth = max(newMaxLineWidth, lineWidthCache[i]!);
    }

    lineWidthCache.removeWhere((key, value) => key >= currentLineCount);

    if ((newMaxLineWidth + lineWidthBuffer) != maxLineWidth) {
      setState(() {
        maxLineWidth = newMaxLineWidth + lineWidthBuffer;
      });
    }
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final bool isControlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    if (isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        _handleCopy();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyX) {
        _handleCut();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyV) {
        _handlePaste();
        return KeyEventResult.handled;
      }
    }

    setState(() {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          editingCore.moveCursor(-1, 0);
          break;
        case LogicalKeyboardKey.arrowRight:
          editingCore.moveCursor(1, 0);
          break;
        case LogicalKeyboardKey.arrowUp:
          editingCore.moveCursor(0, -1);
          break;
        case LogicalKeyboardKey.arrowDown:
          editingCore.moveCursor(0, 1);
          break;
        case LogicalKeyboardKey.enter:
          editingCore.insertText('\n');
          break;
        case LogicalKeyboardKey.backspace:
          editingCore.handleBackspace();
          break;
        case LogicalKeyboardKey.delete:
          editingCore.handleDelete();
          break;
        case LogicalKeyboardKey.tab:
          editingCore.insertText('    ');
          break;
        default:
          if (event.character != null) editingCore.insertText(event.character!);
      }
    });
    return KeyEventResult.handled;
  }

  int _getPositionFromOffset(Offset offset) {
    final adjustedOffset =
        offset + Offset(horizontalController.offset, verticalController.offset);
    final tappedLine = (adjustedOffset.dy / lineHeight).floor();

    if (editingCore.lineCount == 0) return 0;

    if (tappedLine < editingCore.lineCount) {
      final tappedOffset =
          (adjustedOffset.dx - lineNumberWidth).clamp(0, double.infinity);
      final column =
          (tappedOffset / charWidth).round().clamp(0, double.infinity).toInt();

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

  void _handleTap(TapDownDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.cursorPosition = position;
      editingCore.clearSelection();
    });
    focusNode.requestFocus();
  }

  void _updateSelection(DragStartDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.setSelection(position, position);
    });
  }

  void _updateSelectionOnDrag(DragUpdateDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.setSelection(
          editingCore.selectionStart ?? position, position);
    });
    _autoScrollOnDrag(details.localPosition);
  }

  void _autoScrollOnDrag(Offset position) {
    const scrollThreshold = 50.0;
    const scrollStep = 16.0;

    if (position.dy < scrollThreshold && verticalController.offset > 0) {
      verticalController.jumpTo(max(0, verticalController.offset - scrollStep));
    } else if (position.dy > context.size!.height - scrollThreshold &&
        verticalController.offset <
            verticalController.position.maxScrollExtent) {
      verticalController.jumpTo(min(verticalController.position.maxScrollExtent,
          verticalController.offset + scrollStep));
    }

    if (position.dx < scrollThreshold && horizontalController.offset > 0) {
      horizontalController
          .jumpTo(max(0, horizontalController.offset - scrollStep));
    } else if (position.dx > context.size!.width - scrollThreshold &&
        horizontalController.offset <
            horizontalController.position.maxScrollExtent) {
      horizontalController.jumpTo(min(
          horizontalController.position.maxScrollExtent,
          horizontalController.offset + scrollStep));
    }
  }

  void _handleCopy() async {
    if (editingCore.hasSelection()) {
      await Clipboard.setData(
          ClipboardData(text: editingCore.getSelectedText()));
    }
  }

  void _handleCut() async {
    if (editingCore.hasSelection()) {
      await Clipboard.setData(
          ClipboardData(text: editingCore.getSelectedText()));
      editingCore.deleteSelection();
      setState(() {});
    }
  }

  void _handlePaste() async {
    ClipboardData? clipboardData =
        await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      editingCore.insertText(clipboardData!.text!);
      _updateVisibleLines();
      _calculateMaxLineWidth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Colors.white,
          child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor:
                    WidgetStateProperty.all(Colors.grey.withOpacity(0.6)),
              ),
              child: GestureDetector(
                onTapDown: _handleTap,
                onPanStart: _updateSelection,
                onPanUpdate: _updateSelectionOnDrag,
                child: Focus(
                  focusNode: focusNode,
                  onKeyEvent: _handleKeyPress,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: lineNumberWidth,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            controller: lineNumberController,
                            child: SizedBox(
                              height: max(editingCore.lineCount * lineHeight,
                                  constraints.maxHeight),
                              child: LineNumbers(
                                lineCount: editingCore.lineCount,
                                lineHeight: lineHeight,
                                lineNumberWidth: lineNumberWidth,
                                firstVisibleLine: firstVisibleLine,
                                visibleLineCount: visibleLineCount,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Scrollbar(
                              radius: Radius.zero,
                              controller: verticalController,
                              child: Scrollbar(
                                radius: Radius.zero,
                                controller: horizontalController,
                                notificationPredicate: (notification) =>
                                    notification.depth == 1,
                                child: SingleChildScrollView(
                                  controller: verticalController,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: horizontalController,
                                    child: SizedBox(
                                      width: max(
                                          maxLineWidth - lineNumberWidth,
                                          constraints.maxWidth -
                                              lineNumberWidth),
                                      height: max(
                                          editingCore.lineCount * lineHeight,
                                          constraints.maxHeight),
                                      child: CustomPaint(
                                        painter: CodeEditorPainter(
                                          version: editingCore.version,
                                          editingCore: editingCore,
                                          firstVisibleLine: firstVisibleLine,
                                          visibleLineCount: visibleLineCount,
                                          horizontalOffset:
                                              horizontalController.hasClients
                                                  ? horizontalController.offset
                                                  : 0,
                                        ),
                                        size: Size(
                                          max(
                                              maxLineWidth - lineNumberWidth,
                                              constraints.maxWidth -
                                                  lineNumberWidth),
                                          editingCore.lineCount * lineHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                width: scrollbarWidth,
                                height: scrollbarWidth,
                                child: ColoredBox(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        );
      },
    );
  }

  @override
  void dispose() {
    editingCore.removeListener(_onTextChanged);
    editingCore.dispose();
    verticalController.dispose();
    horizontalController.dispose();
    lineNumberController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
