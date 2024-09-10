import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight/models/rope.dart';

class CodeEditor extends StatefulWidget {
  final String initialCode;
  const CodeEditor({super.key, required this.initialCode});

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late Rope rope;
  late ScrollController _verticalController, _horizontalController;
  final FocusNode _focusNode = FocusNode();

  int _firstVisibleLine = 0, _visibleLineCount = 0;
  int _cursorLine = 0, _cursorColumn = 0;
  int? _selectionStartLine,
      _selectionStartColumn,
      _selectionEndLine,
      _selectionEndColumn;
  double _maxLineWidth = 0.0;

  @override
  void initState() {
    super.initState();
    rope = Rope(widget.initialCode);
    _verticalController = ScrollController()..addListener(_updateVisibleLines);
    _horizontalController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxLineWidth();
      _updateVisibleLines();
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
    _maxLineWidth =
        rope.getLineCount().toString().length * CodeEditorPainter.charWidth +
            CodeEditorPainter.lineNumberWidth;
    for (int i = 0; i < rope.getLineCount(); i++) {
      double lineWidth =
          rope.getLineContent(i).length * CodeEditorPainter.charWidth +
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
          _moveCursor(-1, 0);
        case LogicalKeyboardKey.arrowRight:
          _moveCursor(1, 0);
        case LogicalKeyboardKey.arrowUp:
          _moveCursor(0, -1);
        case LogicalKeyboardKey.arrowDown:
          _moveCursor(0, 1);
        case LogicalKeyboardKey.enter:
          _insertText('\n');
        case LogicalKeyboardKey.backspace:
          _handleBackspace();
        case LogicalKeyboardKey.delete:
          _handleDelete();
        case LogicalKeyboardKey.tab:
          _insertText('    ');
        default:
          if (event.character != null) _insertText(event.character!);
      }
    });
    return KeyEventResult.handled;
  }

  void _moveCursor(int horizontalMove, int verticalMove) {
    if (verticalMove != 0) {
      _cursorLine =
          (_cursorLine + verticalMove).clamp(0, rope.getLineCount() - 1);
    } else if (horizontalMove != 0) {
      if (horizontalMove > 0 &&
          _cursorColumn == rope.getLineContent(_cursorLine).length) {
        if (_cursorLine < rope.getLineCount() - 1) {
          _cursorLine++;
          _cursorColumn = 0;
        }
      } else if (horizontalMove < 0 && _cursorColumn == 0) {
        if (_cursorLine > 0) {
          _cursorLine--;
          _cursorColumn = rope.getLineContent(_cursorLine).length;
        }
      } else {
        _cursorColumn = (_cursorColumn + horizontalMove)
            .clamp(0, rope.getLineContent(_cursorLine).length);
      }
    }
  }

  void _insertText(String text) {
    if (_hasSelection()) _deleteSelection();
    int insertIndex = rope.getLineStartFromIndex(_cursorLine) + _cursorColumn;
    rope.insert(insertIndex, text);
    List<String> lines = text.split('\n');
    if (lines.length > 1) {
      _cursorLine += lines.length - 1;
      _cursorColumn = lines.last.length;
    } else {
      _cursorColumn += text.length;
    }
    _clearSelection();
  }

  void _handleBackspace() {
    if (_hasSelection()) {
      _deleteSelection();
    } else if (_cursorColumn > 0) {
      final lineStart = rope.getLineStartFromIndex(_cursorLine);
      rope.delete(lineStart + _cursorColumn - 1, 1);
      _cursorColumn--;
    } else if (_cursorLine > 0) {
      final previousLineEnd = rope.getLineEndFromIndex(_cursorLine - 1);
      final currentLineContent = rope.getLineContent(_cursorLine);
      rope.delete(previousLineEnd, 1);
      _cursorLine--;
      _cursorColumn = rope.getLineContent(_cursorLine).length;
      rope.insert(rope.getLineEndFromIndex(_cursorLine), currentLineContent);
    }
    _clearSelection();
  }

  void _handleDelete() {
    if (_hasSelection()) {
      _deleteSelection();
    } else if (_cursorColumn < rope.getLineContent(_cursorLine).length) {
      final lineStart = rope.getLineStartFromIndex(_cursorLine);
      rope.delete(lineStart + _cursorColumn, 1);
    } else if (_cursorLine < rope.getLineCount() - 1) {
      final nextLineContent = rope.getLineContent(_cursorLine + 1);
      rope.delete(rope.getLineEndFromIndex(_cursorLine), 1);
      rope.insert(rope.getLineEndFromIndex(_cursorLine), nextLineContent);
    }
    _clearSelection();
  }

  void _handleCopy() async {
    if (_hasSelection()) {
      await Clipboard.setData(ClipboardData(text: _getSelectedText()));
    }
  }

  void _handleCut() async {
    if (_hasSelection()) {
      await Clipboard.setData(ClipboardData(text: _getSelectedText()));
      _deleteSelection();
    }
  }

  void _handlePaste() async {
    ClipboardData? clipboardData =
        await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      if (_hasSelection()) _deleteSelection();
      _insertText(clipboardData!.text!);
    }
  }

  bool _hasSelection() =>
      _selectionStartLine != null && _selectionEndLine != null;

  String _getSelectedText() {
    if (!_hasSelection()) return '';
    int startLine = min(_selectionStartLine!, _selectionEndLine!);
    int endLine = max(_selectionStartLine!, _selectionEndLine!);
    int startColumn = startLine == _selectionStartLine!
        ? _selectionStartColumn!
        : _selectionEndColumn!;
    int endColumn = endLine == _selectionEndLine!
        ? _selectionEndColumn!
        : _selectionStartColumn!;

    String selectedText = '';
    for (int i = startLine; i <= endLine; i++) {
      String lineContent = rope.getLineContent(i);
      if (i == startLine && i == endLine) {
        selectedText += lineContent.substring(startColumn, endColumn);
      } else if (i == startLine) {
        selectedText += '${lineContent.substring(startColumn)}\n';
      } else if (i == endLine) {
        selectedText += lineContent.substring(0, endColumn);
      } else {
        selectedText += '$lineContent\n';
      }
    }
    return selectedText;
  }

  void _deleteSelection() {
    if (!_hasSelection()) return;
    int startLine = min(_selectionStartLine!, _selectionEndLine!);
    int endLine = max(_selectionStartLine!, _selectionEndLine!);
    int startColumn = startLine == _selectionStartLine!
        ? _selectionStartColumn!
        : _selectionEndColumn!;
    int endColumn = endLine == _selectionEndLine!
        ? _selectionEndColumn!
        : _selectionStartColumn!;

    int startIndex = rope.getLineStartFromIndex(startLine) + startColumn;
    int endIndex = rope.getLineStartFromIndex(endLine) + endColumn;

    rope.delete(startIndex, endIndex - startIndex);

    _cursorLine = startLine;
    _cursorColumn = startColumn;
    _clearSelection();
  }

  void _clearSelection() {
    _selectionStartLine =
        _selectionStartColumn = _selectionEndLine = _selectionEndColumn = null;
  }

  void _handleTap(TapDownDetails details) {
    final tapPosition = details.localPosition;
    final tappedLine = (tapPosition.dy / CodeEditorPainter.lineHeight).floor() +
        _firstVisibleLine;
    if (tappedLine < rope.getLineCount()) {
      setState(() {
        _cursorLine = tappedLine;
        final tappedOffset = tapPosition.dx - CodeEditorPainter.lineNumberWidth;
        _cursorColumn = _calculateColumnFromOffset(
            tappedOffset, rope.getLineContent(_cursorLine));
        _clearSelection();
      });
    }
    _focusNode.requestFocus();
  }

  int _calculateColumnFromOffset(double offset, String line) {
    final textPainter = TextPainter(
      text: TextSpan(text: line, style: const TextStyle(fontSize: 20)),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.getPositionForOffset(Offset(offset, 0)).offset;
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
                        rope.getLineCount() * CodeEditorPainter.lineHeight,
                        constraints.maxHeight),
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: CustomPaint(
                        painter: CodeEditorPainter(
                          rope: rope,
                          firstVisibleLine: _firstVisibleLine,
                          visibleLineCount: _visibleLineCount,
                          cursorLine: _cursorLine,
                          cursorColumn: _cursorColumn,
                          selectionStartLine: _selectionStartLine,
                          selectionStartColumn: _selectionStartColumn,
                          selectionEndLine: _selectionEndLine,
                          selectionEndColumn: _selectionEndColumn,
                          horizontalOffset: _horizontalController.hasClients
                              ? _horizontalController.offset
                              : 0,
                        ),
                        size: Size(max(_maxLineWidth, constraints.maxWidth),
                            rope.getLineCount() * CodeEditorPainter.lineHeight),
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
    if (tappedLine < rope.getLineCount()) {
      setState(() {
        if (isStart) {
          _selectionStartLine = _selectionEndLine = tappedLine;
          final tappedOffset = tapPosition.dx +
              _horizontalController.offset -
              CodeEditorPainter.lineNumberWidth;
          _selectionStartColumn = _selectionEndColumn =
              _calculateColumnFromOffset(
                  tappedOffset, rope.getLineContent(tappedLine));
        } else {
          _selectionEndLine = tappedLine;
          final tappedOffset = tapPosition.dx +
              _horizontalController.offset -
              CodeEditorPainter.lineNumberWidth;
          _selectionEndColumn = _calculateColumnFromOffset(
              tappedOffset, rope.getLineContent(tappedLine));
        }
      });
    }
  }

  void _updateSelectionOnDrag(DragUpdateDetails details) {
    final tapPosition = details.localPosition;
    final tappedLine = ((tapPosition.dy + _verticalController.offset) /
            CodeEditorPainter.lineHeight)
        .floor();
    if (tappedLine < rope.getLineCount()) {
      setState(() {
        _selectionEndLine = tappedLine;
        final tappedOffset = tapPosition.dx +
            _horizontalController.offset -
            CodeEditorPainter.lineNumberWidth;
        _selectionEndColumn = _calculateColumnFromOffset(
            tappedOffset, rope.getLineContent(tappedLine));
      });
    }
  }
}

class CodeEditorPainter extends CustomPainter {
  static const double lineHeight = 24.0;
  static const double charWidth = 10.0;
  static const double lineNumberWidth = 50.0;

  final Rope rope;
  final int firstVisibleLine;
  final int visibleLineCount;
  final int cursorLine;
  final int cursorColumn;
  final int? selectionStartLine;
  final int? selectionStartColumn;
  final int? selectionEndLine;
  final int? selectionEndColumn;
  final double horizontalOffset;

  final TextStyle _lineNumberStyle =
      TextStyle(fontSize: 14, color: Colors.grey[600]);
  final TextStyle _textStyle =
      const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'Courier');

  CodeEditorPainter({
    required this.rope,
    required this.firstVisibleLine,
    required this.visibleLineCount,
    required this.cursorLine,
    required this.cursorColumn,
    this.selectionStartLine,
    this.selectionStartColumn,
    this.selectionEndLine,
    this.selectionEndColumn,
    required this.horizontalOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = firstVisibleLine;
        i < firstVisibleLine + visibleLineCount;
        i++) {
      if (i >= rope.getLineCount()) break;

      final lineContent = rope.getLineContent(i);
      final lineNumber =
          '${i + 1}'.padLeft(rope.getLineCount().toString().length);

      // Paint line number background
      canvas.drawRect(
        Rect.fromLTWH(0, i * lineHeight, lineNumberWidth, lineHeight),
        Paint()..color = Colors.grey[200]!,
      );

      // Paint line number
      _paintText(
          canvas,
          lineNumber,
          Offset(lineNumberWidth - lineNumberWidth / 2, i * lineHeight),
          _lineNumberStyle,
          TextAlign.right);

      // Paint line content
      _paintText(
          canvas,
          lineContent,
          Offset(lineNumberWidth - horizontalOffset, i * lineHeight),
          _textStyle);

      // Paint selection if needed
      if (_isLineSelected(i)) {
        _paintSelection(canvas, i, lineContent);
      }

      // Paint cursor
      if (i == cursorLine) {
        _paintCursor(canvas, i, lineContent);
      }
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style,
      [TextAlign align = TextAlign.left]) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  void _paintSelection(Canvas canvas, int line, String lineContent) {
    final selectionPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.3);
    final selectionStart = _getSelectionStartForLine(line);
    final selectionEnd = _getSelectionEndForLine(line);

    final textPainter = TextPainter(
      text: TextSpan(text: lineContent, style: _textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final startOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selectionStart), Rect.zero);
    final endOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: selectionEnd), Rect.zero);

    canvas.drawRect(
      Rect.fromLTRB(
        lineNumberWidth + startOffset.dx - horizontalOffset,
        line * lineHeight,
        lineNumberWidth + endOffset.dx - horizontalOffset,
        (line + 1) * lineHeight,
      ),
      selectionPaint,
    );
  }

  void _paintCursor(Canvas canvas, int line, String lineContent) {
    final textPainter = TextPainter(
      text: TextSpan(
          text: lineContent.substring(0, cursorColumn), style: _textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final cursorOffset = textPainter.width;
    canvas.drawLine(
      Offset(
          lineNumberWidth + cursorOffset - horizontalOffset, line * lineHeight),
      Offset(lineNumberWidth + cursorOffset - horizontalOffset,
          (line + 1) * lineHeight),
      Paint()..color = Colors.blue,
    );
  }

  bool _isLineSelected(int line) {
    if (selectionStartLine == null || selectionEndLine == null) return false;
    return line >= min(selectionStartLine!, selectionEndLine!) &&
        line <= max(selectionStartLine!, selectionEndLine!);
  }

  int _getSelectionStartForLine(int line) {
    if (selectionStartLine == null || selectionEndLine == null) return 0;
    if (selectionStartLine! > selectionEndLine! ||
        (selectionStartLine == selectionEndLine &&
            selectionStartColumn! > selectionEndColumn!)) {
      return line == selectionEndLine! ? selectionEndColumn! : 0;
    }
    return line == selectionStartLine! ? selectionStartColumn! : 0;
  }

  int _getSelectionEndForLine(int line) {
    if (selectionStartLine == null || selectionEndLine == null) return 0;
    if (selectionStartLine! > selectionEndLine! ||
        (selectionStartLine == selectionEndLine &&
            selectionStartColumn! > selectionEndColumn!)) {
      return line == selectionStartLine!
          ? selectionStartColumn!
          : rope.getLineContent(line).length;
    }
    return line == selectionEndLine!
        ? selectionEndColumn!
        : rope.getLineContent(line).length;
  }

  @override
  bool shouldRepaint(CodeEditorPainter oldDelegate) {
    return rope != oldDelegate.rope ||
        firstVisibleLine != oldDelegate.firstVisibleLine ||
        visibleLineCount != oldDelegate.visibleLineCount ||
        cursorLine != oldDelegate.cursorLine ||
        cursorColumn != oldDelegate.cursorColumn ||
        selectionStartLine != oldDelegate.selectionStartLine ||
        selectionStartColumn != oldDelegate.selectionStartColumn ||
        selectionEndLine != oldDelegate.selectionEndLine ||
        selectionEndColumn != oldDelegate.selectionEndColumn ||
        horizontalOffset != oldDelegate.horizontalOffset;
  }
}
