import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/editor_painter.dart';
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

  void initState() {
    super.initState();
    editingCore = TextEditingCore(widget.initialCode);
    editingCore.addListener(_onTextChanged);
    _verticalController = ScrollController()..addListener(_updateVisibleLines);
    _horizontalController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
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
    setState(() {
      _calculateMaxLineWidth();
    });
  }

  void _updateVisibleLines() {
    if (!mounted || !_verticalController.hasClients) return;
    setState(() {
      _firstVisibleLine =
          (_verticalController.offset / CodeEditorPainter.lineHeight).floor();
      _visibleLineCount =
          (MediaQuery.of(context).size.height / CodeEditorPainter.lineHeight)
                  .ceil() +
              1;
    });
  }

  void _calculateMaxLineWidth() {
    _maxLineWidth = editingCore.getLineCount().toString().length *
            CodeEditorPainter.charWidth +
        CodeEditorPainter.lineNumberWidth;
    for (int i = 0; i < editingCore.getLineCount(); i++) {
      double lineWidth =
          editingCore.getLineContent(i).length * CodeEditorPainter.charWidth +
              _maxLineWidth;
      if (lineWidth > _maxLineWidth) _maxLineWidth = lineWidth;
    }
    setState(() {});
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

  void _handleTap(TapDownDetails details) {
    final tapPosition = details.localPosition;
    final tappedLine = (tapPosition.dy / CodeEditorPainter.lineHeight).floor() +
        _firstVisibleLine;
    if (tappedLine < editingCore.getLineCount()) {
      setState(() {
        editingCore.cursorLine = tappedLine;
        final tappedOffset = tapPosition.dx - CodeEditorPainter.lineNumberWidth;
        editingCore.cursorColumn = _calculateColumnFromOffset(
            tappedOffset, editingCore.getLineContent(tappedLine));
        editingCore.clearSelection();
      });
    }
    _focusNode.requestFocus();
    editingCore.incrementVersion();
  }

  int _calculateColumnFromOffset(double offset, String line) {
    final textPainter = TextPainter(
      text: TextSpan(text: line, style: const TextStyle(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.getPositionForOffset(Offset(offset, 0)).offset;
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
      setState(() {});
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
                        editingCore.getLineCount() *
                            CodeEditorPainter.lineHeight,
                        constraints.maxHeight),
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: CustomPaint(
                        painter: CodeEditorPainter(
                          editingCore: editingCore,
                          firstVisibleLine: _firstVisibleLine,
                          visibleLineCount: _visibleLineCount,
                          horizontalOffset: _horizontalController.hasClients
                              ? _horizontalController.offset
                              : 0,
                          version: editingCore.version,
                        ),
                        size: Size(
                            max(_maxLineWidth, constraints.maxWidth),
                            editingCore.getLineCount() *
                                CodeEditorPainter.lineHeight),
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

  void _updateSelection(DragStartDetails details, bool isStart) {
    final tapPosition = details.localPosition;
    final tappedLine = ((tapPosition.dy + _verticalController.offset) /
            CodeEditorPainter.lineHeight)
        .floor();
    if (tappedLine < editingCore.getLineCount()) {
      setState(() {
        if (isStart) {
          final tappedOffset = tapPosition.dx +
              _horizontalController.offset -
              CodeEditorPainter.lineNumberWidth;
          final column = _calculateColumnFromOffset(
              tappedOffset, editingCore.getLineContent(tappedLine));
          editingCore.setSelection(tappedLine, column, tappedLine, column);
        } else {
          editingCore.selectionEndLine = tappedLine;
          final tappedOffset = tapPosition.dx +
              _horizontalController.offset -
              CodeEditorPainter.lineNumberWidth;
          editingCore.selectionEndColumn = _calculateColumnFromOffset(
              tappedOffset, editingCore.getLineContent(tappedLine));
        }
      });
    }
  }

  void _updateSelectionOnDrag(DragUpdateDetails details) {
    final tapPosition = details.localPosition;
    final tappedLine = ((tapPosition.dy + _verticalController.offset) /
            CodeEditorPainter.lineHeight)
        .floor();
    if (tappedLine < editingCore.getLineCount()) {
      setState(() {
        editingCore.selectionEndLine = tappedLine;
        final tappedOffset = tapPosition.dx +
            _horizontalController.offset -
            CodeEditorPainter.lineNumberWidth;
        editingCore.selectionEndColumn = _calculateColumnFromOffset(
            tappedOffset, editingCore.getLineContent(tappedLine));
      });
    }
    editingCore.incrementVersion();
  }
}
