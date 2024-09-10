import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/editor_painter.dart';
import 'package:starlight/features/editor/line_numbers.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditor extends StatefulWidget {
  final String initialCode;
  const CodeEditor({super.key, required this.initialCode});

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late TextEditingCore editingCore;
  late ScrollController _verticalController, _horizontalController;
  final FocusNode _focusNode = FocusNode();

  int _firstVisibleLine = 0, _visibleLineCount = 0;
  double _maxLineWidth = 0.0;
  int _lastLineCount = 0;
  final Map<int, double> _lineWidthCache = {};
  static const double _lineWidthBuffer = 50.0;
  late double _lineNumberWidth;

  @override
  void initState() {
    super.initState();
    editingCore = TextEditingCore(widget.initialCode);
    editingCore.addListener(_onTextChanged);
    _verticalController = ScrollController()..addListener(_updateVisibleLines);
    _horizontalController = ScrollController();

    // Initialize charWidth
    _initializeCharWidth();

    _calculateLineNumberWidth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
    });
  }

  void _initializeCharWidth() {
    final TextPainter textPainter = TextPainter(
      text: const TextSpan(
          text: 'X',
          style: TextStyle(
              fontSize: CodeEditorPainter.fontSize, fontFamily: 'Courier')),
      textDirection: TextDirection.ltr,
    )..layout();
    CodeEditorPainter.charWidth = textPainter.width;
  }

  void _calculateLineNumberWidth() {
    final lineCount = editingCore.rope.lineCount;
    final maxLineNumberWidth =
        '$lineCount'.length * CodeEditorPainter.charWidth;
    _lineNumberWidth = maxLineNumberWidth + 40;
  }

  void _updateVisibleLines() {
    if (!mounted || !_verticalController.hasClients) return;
    setState(() {
      _firstVisibleLine =
          (_verticalController.offset / CodeEditorPainter.lineHeight).floor();
      _visibleLineCount =
          (MediaQuery.of(context).size.height / CodeEditorPainter.lineHeight)
              .ceil();
    });
  }

  @override
  void dispose() {
    editingCore.removeListener(_onTextChanged);
    editingCore.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _calculateLineNumberWidth();
    _calculateMaxLineWidth();
    setState(() {});
  }

  void _calculateMaxLineWidth() {
    int currentLineCount = editingCore.rope.lineCount;
    bool needsUpdate = false;

    // Check if line count has changed
    if (currentLineCount != _lastLineCount) {
      _lastLineCount = currentLineCount;
      needsUpdate = true;
    }

    double newMaxLineWidth = _lineNumberWidth;

    for (int i = 0; i < currentLineCount; i++) {
      if (!_lineWidthCache.containsKey(i)) {
        String line = editingCore.rope.sliceLines(i, i + 1)[0];
        double lineWidth = _estimateLineWidth(line) + _lineNumberWidth;
        _lineWidthCache[i] = lineWidth;
        needsUpdate = true;
      }

      if (_lineWidthCache[i]! > newMaxLineWidth) {
        newMaxLineWidth = _lineWidthCache[i]!;
      }
    }

    // Remove cached widths for lines that no longer exist
    _lineWidthCache.removeWhere((key, value) => key >= currentLineCount);

    // Only update state if max line width has changed
    if (needsUpdate || (newMaxLineWidth + _lineWidthBuffer) != _maxLineWidth) {
      setState(() {
        _maxLineWidth = newMaxLineWidth + _lineWidthBuffer;
      });
    }
  }

  double _estimateLineWidth(String line) {
    return line.length * CodeEditorPainter.charWidth;
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final bool isControlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    if (isControlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          _handleCopy();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyX:
          _handleCut();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyV:
          _handlePaste();
          return KeyEventResult.handled;
      }
    }

    setState(() {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          editingCore.moveCursor(-1, 0);
        case LogicalKeyboardKey.arrowRight:
          editingCore.moveCursor(1, 0);
        case LogicalKeyboardKey.arrowUp:
          editingCore.moveCursor(0, -1);
        case LogicalKeyboardKey.arrowDown:
          editingCore.moveCursor(0, 1);
        case LogicalKeyboardKey.enter:
          editingCore.insertText('\n');
        case LogicalKeyboardKey.backspace:
          editingCore.handleBackspace();
        case LogicalKeyboardKey.delete:
          editingCore.handleDelete();
        case LogicalKeyboardKey.tab:
          editingCore.insertText('    ');
        default:
          if (event.character != null) editingCore.insertText(event.character!);
      }
    });
    return KeyEventResult.handled;
  }

  int _getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(_horizontalController.offset, _verticalController.offset);

    final tappedLine =
        (adjustedOffset.dy / CodeEditorPainter.lineHeight).floor();

    // Return 0 for an empty document
    if (editingCore.rope.lineCount == 0) {
      return 0;
    }

    if (tappedLine < editingCore.rope.lineCount) {
      final tappedOffset =
          (adjustedOffset.dx - _lineNumberWidth).clamp(0, double.infinity);

      final column = (tappedOffset / CodeEditorPainter.charWidth)
          .round()
          .clamp(0, double.infinity)
          .toInt();

      if (tappedLine < 0) return 0;
      int lineStartIndex = editingCore.getLineStartIndex(tappedLine);

      String line = editingCore.rope.sliceLines(tappedLine, tappedLine + 1)[0];

      if (line.isEmpty) {
        return lineStartIndex;
      }

      if (column >= line.length) {
        if (tappedLine == editingCore.rope.lineCount - 1) {
          return lineStartIndex + line.length;
        }

        return lineStartIndex + line.length - 1;
      }

      return lineStartIndex + column;
    }

    return editingCore.rope.length;
  }

  void _handleTap(TapDownDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.cursorPosition = position;
      editingCore.clearSelection();
    });
    _focusNode.requestFocus();
    editingCore.incrementVersion();
  }

  void _updateSelection(DragStartDetails details, bool isStart) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      if (isStart) {
        editingCore.setSelection(position, position);
      } else {
        editingCore.setSelection(
            editingCore.selectionStart ?? position, position);
      }
    });
  }

  void _updateSelectionOnDrag(DragUpdateDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.setSelection(
          editingCore.selectionStart ?? position, position);
    });
    editingCore.incrementVersion();

    // Auto-scroll if necessary
    _autoScrollOnDrag(details.localPosition);
  }

  void _autoScrollOnDrag(Offset position) {
    const scrollThreshold = 50.0;
    const scrollStep = 16.0;

    if (position.dy < scrollThreshold && _verticalController.offset > 0) {
      _verticalController
          .jumpTo(max(0, _verticalController.offset - scrollStep));
    } else if (position.dy > context.size!.height - scrollThreshold &&
        _verticalController.offset <
            _verticalController.position.maxScrollExtent) {
      _verticalController.jumpTo(min(
          _verticalController.position.maxScrollExtent,
          _verticalController.offset + scrollStep));
    }

    if (position.dx < scrollThreshold && _horizontalController.offset > 0) {
      _horizontalController
          .jumpTo(max(0, _horizontalController.offset - scrollStep));
    } else if (position.dx > context.size!.width - scrollThreshold &&
        _horizontalController.offset <
            _horizontalController.position.maxScrollExtent) {
      _horizontalController.jumpTo(min(
          _horizontalController.position.maxScrollExtent,
          _horizontalController.offset + scrollStep));
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
          child: GestureDetector(
            onTapDown: _handleTap,
            onPanStart: (details) => _updateSelection(details, true),
            onPanUpdate: _updateSelectionOnDrag,
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyPress,
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalController,
                  child: SizedBox(
                    width: max(_maxLineWidth, constraints.maxWidth),
                    height: max(
                        editingCore.rope.lineCount *
                            CodeEditorPainter.lineHeight,
                        constraints.maxHeight),
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LineNumbers(
                            lineCount: editingCore.rope.lineCount,
                            lineHeight: CodeEditorPainter.lineHeight,
                            lineNumberWidth: _lineNumberWidth,
                            firstVisibleLine: _firstVisibleLine,
                            visibleLineCount: _visibleLineCount,
                          ),
                          Expanded(
                            child: CustomPaint(
                              painter: CodeEditorPainter(
                                editingCore: editingCore,
                                firstVisibleLine: _firstVisibleLine,
                                visibleLineCount: _visibleLineCount,
                                horizontalOffset:
                                    _horizontalController.hasClients
                                        ? _horizontalController.offset
                                        : 0,
                                version: editingCore.version,
                              ),
                              size: Size(
                                  max(_maxLineWidth - _lineNumberWidth,
                                      constraints.maxWidth - _lineNumberWidth),
                                  editingCore.rope.lineCount *
                                      CodeEditorPainter.lineHeight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
