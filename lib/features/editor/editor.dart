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
    horizontalScrollbarController = ScrollController();
    horizontalController.addListener(_syncHorizontalScrollbar);
    _initializeTextPainter();
    _calculateLineNumberWidth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
    });
  }

  void _syncHorizontalScrollbar() {
    if (horizontalController.position.maxScrollExtent > 0) {
      horizontalScrollbarController.jumpTo(horizontalController.offset);
    }
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
  }

  void _onHorizontalScroll() {
    setState(() {
      // This empty setState ensures the widget rebuilds with the new scroll position
    });
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
    if (_lastKnownVersion != editingCore.version) {
      _calculateLineNumberWidth();
      _calculateMaxLineWidth();
      setState(() {});
      _lastKnownVersion = editingCore.version;
    }
  }

  void _calculateMaxLineWidth() {
    double newMaxLineWidth = lineNumberWidth;
    int currentLineCount = editingCore.lineCount;

    // Only recalculate widths for visible lines and a buffer
    int startLine = max(0, firstVisibleLine - 10);
    int endLine =
        min(currentLineCount, firstVisibleLine + visibleLineCount + 10);

    for (int i = startLine; i < endLine; i++) {
      if (!lineWidthCache.containsKey(i) ||
          _lastKnownVersion != editingCore.version) {
        String line = editingCore.getLineContent(i);
        double lineWidth = _calculateLineWidth(line);
        lineWidthCache[i] = lineWidth;
      }
      newMaxLineWidth = max(newMaxLineWidth, lineWidthCache[i]!);
    }

    // Remove cached widths for lines that no longer exist
    lineWidthCache.removeWhere((key, value) => key >= currentLineCount);

    if ((newMaxLineWidth + lineWidthBuffer) != maxLineWidth) {
      setState(() {
        maxLineWidth = newMaxLineWidth + lineWidthBuffer;
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
                    controller: verticalController,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      controller: verticalController,
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
