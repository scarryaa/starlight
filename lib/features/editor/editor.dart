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
  bool _isHorizontalScrolling = false;

  int firstVisibleLine = 0;
  int visibleLineCount = 0;
  double maxLineWidth = 0.0;
  double lineNumberWidth = 0.0;
  Map<int, double> lineWidthCache = {};

  static const double lineHeight = 24.0;
  static const double fontSize = 14.0;
  static late double charWidth;
  static const double scrollbarWidth = 10.0;
  late ScrollController horizontalScrollbarController;
  late TextPainter _textPainter;
  int _lastKnownVersion = -1;

  @override
  void initState() {
    super.initState();
    editingCore = TextEditingCore(widget.initialCode);
    editingCore.addListener(_onTextChanged);
    verticalController = ScrollController()
      ..addListener(() => _syncScroll(isVertical: true));
    horizontalController = ScrollController()..addListener(_onHorizontalScroll);
    lineNumberController = ScrollController()
      ..addListener(() => _syncScroll(isVertical: false));
    horizontalScrollbarController = ScrollController()
      ..addListener(_syncHorizontalScrollbar);
    _initializeTextPainter();
    _calculateLineNumberWidth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
    });
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

  void _onHorizontalScroll() {
    if (!_isHorizontalScrolling &&
        horizontalController.hasClients &&
        horizontalScrollbarController.hasClients) {
      _isHorizontalScrolling = true;
      horizontalScrollbarController.jumpTo(horizontalController.offset);
      _isHorizontalScrolling = false;
    }
    setState(() {
      // This empty setState ensures the widget rebuilds with the new scroll position
    });
  }

  void _initializeTextPainter() {
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: 'X',
        style: TextStyle(fontSize: fontSize, fontFamily: 'Courier'),
      ),
    );
    _textPainter.layout();
    charWidth = _textPainter.width;
  }

  void _calculateLineNumberWidth() {
    final lineCount = editingCore.lineCount;
    final maxLineNumberWidth = '$lineCount'.length * charWidth;
    lineNumberWidth = maxLineNumberWidth + 40;
  }

  void _syncScroll({required bool isVertical}) {
    if (isVertical && !_isLineNumberScrolling) {
      _isLineNumberScrolling = true;
      lineNumberController.jumpTo(verticalController.offset);
      _isLineNumberScrolling = false;
    } else if (!isVertical && !_isVerticalScrolling) {
      _isVerticalScrolling = true;
      verticalController.jumpTo(lineNumberController.offset);
      _isVerticalScrolling = false;
    }
    _updateVisibleLines();
    setState(() {});
  }

  void _updateVisibleLines() {
    if (!mounted || !verticalController.hasClients) return;

    final totalLines = editingCore.lineCount;
    final viewportHeight = verticalController.position.viewportDimension;

    firstVisibleLine = (verticalController.offset / lineHeight)
        .floor()
        .clamp(0, totalLines - 1);
    visibleLineCount = (viewportHeight / lineHeight).ceil() + 1;

    // Ensure we don't try to display more lines than exist
    if (firstVisibleLine + visibleLineCount > totalLines) {
      visibleLineCount = totalLines - firstVisibleLine;
    }
  }

  void _onTextChanged() {
    if (_lastKnownVersion != editingCore.version) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateEditor();
        _calculateMaxLineWidth();
      });
      _lastKnownVersion = editingCore.version;
    }
  }

  void _recalculateEditor() {
    _calculateLineNumberWidth();
    _calculateMaxLineWidth();
    _updateVisibleLines();
    _ensureCursorVisibility();
    setState(() {});
  }

  void _calculateMaxLineWidth() {
    double newMaxLineWidth = 0;
    int currentLineCount = editingCore.lineCount;

    for (int i = 0; i < currentLineCount; i++) {
      String line = editingCore.getLineContent(i);
      double lineWidth = _calculateLineWidth(line);
      lineWidthCache[i] = lineWidth;
      newMaxLineWidth = max(newMaxLineWidth, lineWidth);
    }

    newMaxLineWidth += lineNumberWidth;

    if (newMaxLineWidth != maxLineWidth) {
      setState(() {
        maxLineWidth = newMaxLineWidth;
      });
    }
  }

  double _calculateLineWidth(String line) {
    _textPainter.text = TextSpan(
      text: line,
      style: const TextStyle(fontSize: fontSize, fontFamily: 'Courier'),
    );
    _textPainter.layout(maxWidth: double.infinity);
    return _textPainter.width + lineNumberWidth;
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
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        _handleSelectAll();
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
          _recalculateEditor();
          break;
        case LogicalKeyboardKey.delete:
          editingCore.handleDelete();
          _recalculateEditor();
          break;
        case LogicalKeyboardKey.tab:
          editingCore.insertText('    ');
          break;
        default:
          if (event.character != null) {
            editingCore.insertText(event.character!);
            _recalculateEditor();
          }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCursorVisibility();
    });

    return KeyEventResult.handled;
  }

  void _handleSelectAll() {
    setState(() {
      editingCore.setSelection(0, editingCore.length);
    });
    _recalculateEditor();
  }

  int _getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(max(0, horizontalController.offset), verticalController.offset);
    final tappedLine = (adjustedOffset.dy / lineHeight).floor();

    if (editingCore.lineCount == 0) return 0;

    if (tappedLine < editingCore.lineCount) {
      final tappedOffset = (adjustedOffset.dx).clamp(0, double.infinity);
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

  void _ensureCursorVisibility() {
    if (!verticalController.hasClients || !horizontalController.hasClients) {
      return;
    }

    final cursorPosition =
        editingCore.cursorPosition.clamp(0, editingCore.length);
    int cursorLine;
    int lineStartIndex;
    int cursorColumn;

    if (cursorPosition == editingCore.length) {
      // Handle the case when the cursor is at the very end
      cursorLine = editingCore.lineCount - 1;
      lineStartIndex = editingCore.getLineStartIndex(cursorLine);
      cursorColumn = cursorPosition - lineStartIndex;
    } else {
      cursorLine = editingCore.rope.findLine(cursorPosition);
      lineStartIndex = editingCore.getLineStartIndex(cursorLine);
      cursorColumn = cursorPosition - lineStartIndex;
    }

    // Vertical scrolling
    final cursorY = cursorLine * lineHeight;
    if (cursorY < verticalController.offset) {
      verticalController.jumpTo(cursorY);
    } else if (cursorY >
        verticalController.offset +
            verticalController.position.viewportDimension -
            lineHeight) {
      verticalController.jumpTo(
          cursorY - verticalController.position.viewportDimension + lineHeight);
    }

    // Horizontal scrolling
    final cursorX = cursorColumn * charWidth + lineNumberWidth;
    if (cursorX < horizontalController.offset + lineNumberWidth) {
      horizontalController.jumpTo(cursorX - lineNumberWidth);
    } else if (cursorX >
        horizontalController.offset +
            horizontalController.position.viewportDimension -
            charWidth) {
      horizontalController.jumpTo(cursorX -
          horizontalController.position.viewportDimension +
          charWidth);
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
      final selectedText = editingCore.getSelectedText();
      await Clipboard.setData(ClipboardData(text: selectedText));
      setState(() {
        editingCore.deleteSelection();
      });
      _recalculateEditor();
    }
  }

  void _handlePaste() async {
    ClipboardData? clipboardData =
        await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      editingCore.insertText(clipboardData!.text!);
      _recalculateEditor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLineNumbers(constraints),
              Expanded(
                child: _buildCodeArea(constraints),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineNumbers(BoxConstraints constraints) {
    return SizedBox(
        width: lineNumberWidth,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: lineNumberController,
            child: SizedBox(
              height: max(
                  editingCore.lineCount * lineHeight, constraints.maxHeight),
              child: LineNumbers(
                lineCount: editingCore.lineCount,
                lineHeight: lineHeight,
                lineNumberWidth: lineNumberWidth,
                firstVisibleLine: firstVisibleLine,
                visibleLineCount: visibleLineCount,
              ),
            ),
          ),
        ));
  }

  Widget _buildCodeArea(BoxConstraints constraints) {
    return GestureDetector(
      onTapDown: _handleTap,
      onPanStart: _updateSelection,
      onPanUpdate: _updateSelectionOnDrag,
      behavior: HitTestBehavior.deferToChild,
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: _handleKeyPress,
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.6)),
              radius: Radius.zero),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Scrollbar(
                    interactive: true,
                    controller: verticalController,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      controller: verticalController,
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          controller: horizontalController,
                          child: SizedBox(
                            width: max(maxLineWidth, constraints.maxWidth),
                            height: max(editingCore.lineCount * lineHeight,
                                constraints.maxHeight),
                            child: CustomPaint(
                              painter: CodeEditorPainter(
                                lineNumberWidth: lineNumberWidth,
                                viewportWidth: constraints.maxWidth,
                                version: editingCore.version,
                                editingCore: editingCore,
                                firstVisibleLine: firstVisibleLine,
                                visibleLineCount: visibleLineCount,
                                horizontalOffset:
                                    horizontalController.hasClients
                                        ? horizontalController.offset.clamp(
                                            0.0,
                                            horizontalController
                                                .position.maxScrollExtent)
                                        : 0,
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: scrollbarWidth,
                      child: Scrollbar(
                        controller: horizontalScrollbarController,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: horizontalScrollbarController,
                          child: SizedBox(
                            width: max(maxLineWidth, constraints.maxWidth),
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
    _textPainter.dispose();
    super.dispose();
  }
}
