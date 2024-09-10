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

  @override
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
      _visibleLineCount = (MediaQuery.of(context).size.height /
                  CodeEditorPainter.lineHeight)
              .ceil() +
          1 +
          (_verticalController.offset / CodeEditorPainter.lineHeight).floor();
    });
  }

  void _calculateMaxLineWidth() {
    List<String> lines = editingCore.getText().split('\n');
    _maxLineWidth =
        lines.length.toString().length * CodeEditorPainter.charWidth +
            CodeEditorPainter.lineNumberWidth;
    for (String line in lines) {
      double lineWidth =
          line.length * CodeEditorPainter.charWidth + _maxLineWidth;
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

  int _getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(_horizontalController.offset, _verticalController.offset);
    final tappedLine =
        (adjustedOffset.dy / CodeEditorPainter.lineHeight).floor();
    final lines = editingCore.getText().split('\n');

    if (tappedLine < lines.length) {
      final tappedOffset =
          adjustedOffset.dx - CodeEditorPainter.lineNumberWidth;
      final column = (tappedOffset / CodeEditorPainter.charWidth).round();

      // Calculate the position including empty lines
      int position = 0;
      for (int i = 0; i < tappedLine; i++) {
        position += lines[i].length + 1; // +1 for the newline character
      }
      return position + min(column, lines[tappedLine].length);
    }

    return editingCore.getText().length;
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
                        editingCore.getText().split('\n').length *
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
                            editingCore.getText().split('\n').length *
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
}
