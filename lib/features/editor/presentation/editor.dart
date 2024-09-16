import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide TabBar, Tab;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/domain/enums/selection_mode.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/presentation/editor_painter.dart';
import 'package:starlight/features/editor/presentation/line_numbers.dart';
import 'package:starlight/features/editor/services/syntax_highlighter.dart';
import 'package:starlight/mixins/editor_mixins.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/utils/constants.dart';

class CodeEditor extends StatefulWidget {
  final FocusNode focusNode;
  final String initialCode;
  final String filePath;
  final List<int> matchPositions;
  final String searchTerm;
  final int currentMatchIndex;
  final VoidCallback onSelectPreviousMatch;
  final VoidCallback onSelectNextMatch;
  final VoidCallback onReplace;
  final VoidCallback onReplaceAll;
  final Function(String) onUpdateSearchTerm;
  final Function(String) onUpdateReplaceTerm;
  final int? selectionStart;
  final int? selectionEnd;
  final int? cursorPosition;
  final KeyboardShortcutService keyboardShortcutService;
  final Function(String) onContentChanged;
  final double zoomLevel;

  const CodeEditor({
    super.key,
    required this.initialCode,
    required this.filePath,
    required this.matchPositions,
    required this.searchTerm,
    required this.currentMatchIndex,
    required this.onSelectPreviousMatch,
    required this.onSelectNextMatch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onUpdateSearchTerm,
    required this.onUpdateReplaceTerm,
    required this.keyboardShortcutService,
    required this.onContentChanged,
    required this.zoomLevel,
    required this.focusNode,
    this.selectionStart,
    this.selectionEnd,
    this.cursorPosition,
  });

  @override
  CodeEditorState createState() => CodeEditorState();
}

class CodeEditorState extends State<CodeEditor>
    with CodeEditorScrollMixin<CodeEditor> {
  @override
  late TextEditingCore editingCore;

  @override
  int firstVisibleLine = 0;
  @override
  int visibleLineCount = 0;
  double maxLineWidth = 0.0;
  @override
  double lineNumberWidth = 0.0;
  @override
  double zoomLevel = 1.0;

  final Map<int, double> _lineWidthCache = {};
  int _lastCalculatedLine = -1;
  double _cachedMaxLineWidth = 0;
  int _lastLineCount = 0;
  late TextPainter _textPainter;
  late SyntaxHighlighter _syntaxHighlighter;
  int _lastKnownVersion = -1;
  int _tapCount = 0;
  Timer? _tapTimer;
  SelectionMode _selectionMode = SelectionMode.character;
  int? _selectionAnchor;
  Offset? _lastTapPosition;

  void maintainFocus() {
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _initializeTextPainter(context);

    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
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

  @override
  void didUpdateWidget(CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionStart != null &&
        widget.selectionEnd != null &&
        widget.cursorPosition != null) {
      editingCore.setSelection(widget.selectionStart!, widget.selectionEnd!);
      editingCore.cursorPosition = widget.cursorPosition!;
      if (widget.filePath != oldWidget.filePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadFile();
        });
      }
    }
  }

  @override
  void dispose() {
    editingCore.removeListener(_onTextChanged);
    editingCore.dispose();
    _textPainter.dispose();
    super.dispose();
  }

  int getPositionAtColumn(int line, int column) {
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    return min(lineStart + column, lineEnd);
  }

  @override
  void initState() {
    super.initState();
    try {
      editingCore = TextEditingCore("\n");
      editingCore.setText(widget.initialCode);
      if (widget.initialCode.isEmpty) {
        editingCore.handleBackspace();
      }
    } catch (e) {
      print('Error initializing TextEditingCore: $e');
      editingCore = TextEditingCore('\n');
    }

    editingCore.addListener(_onTextChanged);

    _syntaxHighlighter = SyntaxHighlighter({
      'keyword':
          const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      'type': const TextStyle(color: Colors.green),
      'comment':
          const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      'string': const TextStyle(color: Colors.red),
      'number': const TextStyle(color: Colors.purple),
      'function': const TextStyle(color: Colors.orange),
      'default': const TextStyle(color: Colors.black),
    }, language: 'dart');
    _calculateLineNumberWidth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMaxLineWidth();
      updateVisibleLines();
    });
  }

  Widget _buildCodeArea(BoxConstraints constraints) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: _handleTap,
      onPanStart: _updateSelection,
      onPanUpdate: _updateSelectionOnDrag,
      onPanEnd: (details) {
        _selectionAnchor = null;
        _selectionMode = SelectionMode.character;
      },
      behavior: HitTestBehavior.deferToChild,
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: _handleKeyPress,
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(
                  theme.colorScheme.secondary.withOpacity(0.6)),
              radius: Radius.zero),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Scrollbar(
                    interactive: true,
                    controller: codeScrollController,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      controller: codeScrollController,
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: horizontalController,
                          child: SizedBox(
                            width: max(maxLineWidth, constraints.maxWidth),
                            height: max(
                                editingCore.lineCount *
                                    CodeEditorConstants.lineHeight,
                                constraints.maxHeight),
                            child: CustomPaint(
                              painter: CodeEditorPainter(
                                syntaxHighlighter: _syntaxHighlighter,
                                zoomLevel: widget.zoomLevel,
                                matchPositions: widget.matchPositions,
                                searchTerm: widget.searchTerm,
                                highlightColor: theme.colorScheme.secondary
                                    .withOpacity(0.3),
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
                                textStyle: theme.textTheme.bodyMedium!
                                    .copyWith(fontFamily: 'Courier'),
                                selectionColor:
                                    theme.colorScheme.primary.withOpacity(0.3),
                                cursorColor: theme.colorScheme.primary,
                                cursorPosition: editingCore.cursorPosition,
                                selectionStart: editingCore.selectionStart,
                                selectionEnd: editingCore.selectionEnd,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: CodeEditorConstants.scrollbarWidth + 2,
                      height: CodeEditorConstants.scrollbarWidth,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: CodeEditorConstants.scrollbarWidth,
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

  Widget _buildLineNumbers(BoxConstraints constraints) {
    final theme = Theme.of(context);
    final scaledLineNumberWidth = lineNumberWidth * widget.zoomLevel;
    final scaledLineHeight = CodeEditorConstants.lineHeight * widget.zoomLevel;

    return SizedBox(
      width: scaledLineNumberWidth,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: lineNumberScrollController,
          child: SizedBox(
            height: max(editingCore.lineCount * scaledLineHeight,
                constraints.maxHeight),
            child: LineNumbers(
              lineCount: editingCore.lineCount,
              lineHeight: CodeEditorConstants.lineHeight,
              lineNumberWidth: lineNumberWidth,
              firstVisibleLine: firstVisibleLine,
              visibleLineCount: visibleLineCount,
              zoomLevel: widget.zoomLevel,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _calculateLineNumberWidth() {
    final lineCount = editingCore.lineCount;
    final maxLineNumberWidth =
        '$lineCount'.length * CodeEditorConstants.charWidth;
    lineNumberWidth = maxLineNumberWidth + 40;
  }

  double _calculateLineWidth(String line) {
    return line.length * CodeEditorConstants.charWidth;
  }

  void _extendSelectionByLineFromAnchor(int anchor, int extent) {
    int anchorLine = editingCore.rope.findLine(anchor);
    int extentLine = editingCore.rope.findLine(extent);

    int newStart = editingCore.getLineStartIndex(min(anchorLine, extentLine));
    int newEnd = editingCore.getLineEndIndex(max(anchorLine, extentLine));

    if (extent >= anchor) {
      // Dragging forward
      editingCore.setSelection(anchor, newEnd);
    } else {
      // Dragging backward
      editingCore.setSelection(newStart, anchor);
    }
  }

  void _extendSelectionByWordFromAnchor(int anchor, int extent) {
    int newStart, newEnd;

    if (extent >= anchor) {
      // Dragging forward
      _selectWordAtPosition(extent);
      newStart = anchor;
      newEnd = editingCore.selectionEnd!;
    } else {
      // Dragging backward
      _selectWordAtPosition(extent);
      newStart = editingCore.selectionStart!;
      newEnd = anchor;
    }

    editingCore.setSelection(newStart, newEnd);
  }

  int _findWordOrSymbolGroupEnd(String text, int position, int lineEnd) {
    bool isSymbol = _isSymbol(text[position]);
    int end = position;

    while (end < lineEnd) {
      if (isSymbol) {
        if (!_isSymbol(text[end])) break;
      } else {
        if (_isWordBoundary(text[end])) break;
      }
      end++;
    }

    return end;
  }

  int _findWordOrSymbolGroupStart(String text, int position, int lineStart) {
    bool isSymbol = _isSymbol(text[position]);
    int start = position;

    while (start > lineStart) {
      if (isSymbol) {
        if (!_isSymbol(text[start - 1])) break;
      } else {
        if (_isWordBoundary(text[start - 1])) break;
      }
      start--;
    }

    return start;
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

  void _handleDoubleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    setState(() {
      _selectWordAtPosition(position);
    });
    widget.focusNode.requestFocus();
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_handleShortcuts(event)) {
      return KeyEventResult.handled;
    }

    if (_handleSelectionKeys(event)) {
      return KeyEventResult.handled;
    }

    if (_handleTextInputKeys(event)) {
      return KeyEventResult.handled;
    }

    ensureCursorVisibility();
    return KeyEventResult.handled;
  }

  bool _handleShortcuts(KeyEvent event) {
    final bool isControlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    if (isControlPressed) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          _handleCopy();
          return true;
        case LogicalKeyboardKey.keyX:
          _handleCut();
          return true;
        case LogicalKeyboardKey.keyV:
          _handlePaste();
          return true;
        case LogicalKeyboardKey.keyA:
          _handleSelectAll();
          return true;
      }
    }
    return false;
  }

  bool _handleSelectionKeys(KeyEvent event) {
    if (editingCore.hasSelection()) {
      int selectionStart = editingCore.selectionStart!;
      int selectionEnd = editingCore.selectionEnd!;
      bool isBackwardSelection = selectionEnd < selectionStart;
      int actualStart = min(selectionStart, selectionEnd);
      int actualEnd = max(selectionStart, selectionEnd);

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          editingCore.cursorPosition =
              isBackwardSelection ? actualEnd : actualStart;
          editingCore.clearSelection();
          return true;
        case LogicalKeyboardKey.arrowRight:
          editingCore.cursorPosition =
              isBackwardSelection ? actualStart : actualEnd;
          editingCore.clearSelection();
          return true;
        case LogicalKeyboardKey.arrowUp:
          _handleSelectionArrowUp(isBackwardSelection, actualStart, actualEnd);
          return true;
        case LogicalKeyboardKey.arrowDown:
          _handleSelectionArrowDown(
              isBackwardSelection, actualStart, actualEnd);
          return true;
      }
    }
    return false;
  }

  void _handleSelectionArrowUp(
      bool isBackwardSelection, int actualStart, int actualEnd) {
    int targetLine = editingCore.rope
        .findLine(isBackwardSelection ? actualEnd : actualStart);
    if (targetLine > 0) {
      int column = (isBackwardSelection ? actualEnd : actualStart) -
          editingCore.getLineStartIndex(targetLine);
      int newLine = targetLine - 1;
      int newPosition = getPositionAtColumn(newLine, column);
      editingCore.cursorPosition = newPosition;
    } else {
      editingCore.cursorPosition =
          isBackwardSelection ? actualEnd : actualStart;
    }
    editingCore.clearSelection();
  }

  void _handleSelectionArrowDown(
      bool isBackwardSelection, int actualStart, int actualEnd) {
    int targetLine = editingCore.rope
        .findLine(isBackwardSelection ? actualStart : actualEnd);
    if (targetLine < editingCore.lineCount - 1) {
      int column = (isBackwardSelection ? actualStart : actualEnd) -
          editingCore.getLineStartIndex(targetLine);
      int newLine = targetLine + 1;
      int newPosition = getPositionAtColumn(newLine, column);
      editingCore.cursorPosition = newPosition;
    } else {
      editingCore.cursorPosition =
          isBackwardSelection ? actualStart : actualEnd;
    }
    editingCore.clearSelection();
  }

  bool _handleTextInputKeys(KeyEvent event) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        editingCore.moveCursor(-1, 0);
        return true;
      case LogicalKeyboardKey.arrowRight:
        editingCore.moveCursor(1, 0);
        return true;
      case LogicalKeyboardKey.arrowUp:
        editingCore.moveCursor(0, -1);
        return true;
      case LogicalKeyboardKey.arrowDown:
        editingCore.moveCursor(0, 1);
        return true;
      case LogicalKeyboardKey.enter:
        editingCore.insertText('\n');
        return true;
      case LogicalKeyboardKey.backspace:
        editingCore.handleBackspace();
        _recalculateEditor();
        return true;
      case LogicalKeyboardKey.delete:
        editingCore.handleDelete();
        _recalculateEditor();
        return true;
      case LogicalKeyboardKey.tab:
        editingCore.insertText(' ');
        return true;
      default:
        if (event.character != null) {
          editingCore.insertText(event.character!);
          _recalculateEditor();
          return true;
        }
    }
    return false;
  }

  void _handlePaste() async {
    ClipboardData? clipboardData =
        await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      editingCore.insertText(clipboardData!.text!);
      _recalculateEditor();
    }
  }

  void _handleSelectAll() {
    setState(() {
      editingCore.setSelection(0, editingCore.length);
    });
    _recalculateEditor();
  }

  void _handleSingleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.cursorPosition = position;
      editingCore.clearSelection();
    });
    widget.focusNode.requestFocus();
  }

  void _handleTap(TapDownDetails details) {
    if (_lastTapPosition != null) {
      double distance = (details.localPosition - _lastTapPosition!).distance;
      if (distance > CodeEditorConstants.clickDistanceThreshold) {
        // If the new tap is too far from the last one, reset the tap count
        _tapCount = 0;
      }
    }

    _tapCount++;
    _lastTapPosition = details.localPosition;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 500), () {
      _tapCount = 0;
      _lastTapPosition = null;
    });

    if (_tapCount == 1) {
      _selectionMode = SelectionMode.character;
      _handleSingleTap(details);
    } else if (_tapCount == 2) {
      _selectionMode = SelectionMode.word;
      _handleDoubleTap(details);
    } else if (_tapCount == 3) {
      _selectionMode = SelectionMode.line;
      _handleTripleTap(details);
    }
  }

  void _handleTripleTap(TapDownDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    setState(() {
      _selectLineAtPosition(position);
    });
    widget.focusNode.requestFocus();
  }

  void _initializeTextPainter(BuildContext context) {
    final theme = Theme.of(context);
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'X',
        style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'Courier'),
      ),
    );
    _textPainter.layout();
    CodeEditorConstants.charWidth = _textPainter.width;
  }

  bool _isCompoundOperator(String sequence) {
    final compoundOperators = [
      '++;',
      '--;',
      '+=',
      '-=',
      '*=',
      '/=',
      '%=',
      '&=',
      '|=',
      '^=',
      '>>=',
      '<<='
    ];
    return compoundOperators.any((op) => sequence.endsWith(op));
  }

  bool _isSymbol(String char) {
    return char.trim().isNotEmpty && _isWordBoundary(char);
  }

  bool _isWordBoundary(String character) {
    return character.trim().isEmpty ||
        '.,;:!?()[]{}+-*/%&|^<>=!~'.contains(character);
  }

  void _loadFile() {
    if (widget.filePath.isNotEmpty) {
      try {
        final file = File(widget.filePath);
        final content = file.readAsStringSync();
        setState(() {
          editingCore.setText(content);
          editingCore.cursorPosition = 1;
          editingCore.clearSelection();
        });

        SchedulerBinding.instance.addPostFrameCallback((_) {
          resetAllScrollPositions();
          _recalculateEditor();
        });
      } catch (e, stackTrace) {
        print('Error loading file: $e');
        print("Stack trace: $stackTrace");
      }
    }
  }

  void _onTextChanged() {
    if (_lastKnownVersion != editingCore.version) {
      _syntaxHighlighter.updateLine(
          editingCore.lastModifiedLine, editingCore.version);
      setState(() {});
      widget.onContentChanged(editingCore.getText());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateEditor();
        widget.focusNode.requestFocus();
      });
      _lastKnownVersion = editingCore.version;
    }
  }

  void _recalculateEditor() {
    _calculateLineNumberWidth();
    _updateMaxLineWidth();
    updateVisibleLines();
    ensureCursorVisibility();
    setState(() {});
  }

  void _selectLineAtPosition(int position) {
    int line = editingCore.rope.findLine(position);
    int lineStart = editingCore.getLineStartIndex(line);
    int lineEnd = editingCore.getLineEndIndex(line);
    editingCore.setSelection(lineStart, lineEnd);
    editingCore.cursorPosition =
        lineEnd; // Place cursor at the end of selection
  }

  void _selectWordAtPosition(int position) {
    String text = editingCore.getText();
    if (text.isEmpty) return;

    // Find the start and end of the current line
    int lineStart = position;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = position;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }

    // Check if the click is beyond the last non-whitespace character
    int lastNonWhitespace = lineEnd - 1;
    while (lastNonWhitespace > lineStart &&
        text[lastNonWhitespace].trim().isEmpty) {
      lastNonWhitespace--;
    }

    if (position > lastNonWhitespace) {
      // Click is beyond the last word, so select the last word or special characters
      int wordEnd = lastNonWhitespace + 1;
      int wordStart = wordEnd;

      // Check for compound operators or special character sequences at the end
      String endSequence = text.substring(max(lineStart, wordEnd - 3), wordEnd);
      if (_isCompoundOperator(endSequence)) {
        wordStart = wordEnd - endSequence.length;
      } else {
        // Select the last word or symbol group
        wordStart = _findWordOrSymbolGroupStart(text, wordEnd - 1, lineStart);
      }
      editingCore.setSelection(wordStart, wordEnd);
    } else {
      // Normal word, symbol, or whitespace selection
      int start = position;
      int end = position;

      if (text[position].trim().isEmpty) {
        // Select contiguous whitespace within the same line
        while (start > lineStart && text[start - 1].trim().isEmpty) {
          start--;
        }
        while (end < lineEnd && text[end].trim().isEmpty) {
          end++;
        }
      } else {
        // Word or symbol group selection
        start = _findWordOrSymbolGroupStart(text, position, lineStart);
        end = _findWordOrSymbolGroupEnd(text, position, lineEnd);
      }

      editingCore.setSelection(start, end);
      editingCore.cursorPosition = end; // Place cursor at the end of selection
    }
  }

  void _updateMaxLineWidth() {
    int currentLineCount = editingCore.lineCount;
    double newMaxLineWidth = _cachedMaxLineWidth;

    // Only recalculate if the line count has changed
    if (currentLineCount != _lastLineCount) {
      // Check for deleted lines
      if (currentLineCount < _lastLineCount) {
        _lineWidthCache.removeWhere((key, value) => key >= currentLineCount);
        // Recalculate max width if we removed the previously longest line
        if (_cachedMaxLineWidth == newMaxLineWidth) {
          newMaxLineWidth = _lineWidthCache.values.fold(0, max);
        }
      }

      // Calculate only new lines
      for (int i = _lastCalculatedLine + 1; i < currentLineCount; i++) {
        String line = editingCore.getLineContent(i);
        double lineWidth = _calculateLineWidth(line);
        _lineWidthCache[i] = lineWidth;
        newMaxLineWidth = max(newMaxLineWidth, lineWidth);
      }

      _lastCalculatedLine = currentLineCount - 1;
      _lastLineCount = currentLineCount;
    } else {
      // If line count hasn't changed, we only need to check the last modified line
      int lastModifiedLine = editingCore.lastModifiedLine;
      if (lastModifiedLine >= 0 && lastModifiedLine < currentLineCount) {
        String line = editingCore.getLineContent(lastModifiedLine);
        double lineWidth = _calculateLineWidth(line);
        _lineWidthCache[lastModifiedLine] = lineWidth;
        newMaxLineWidth = max(newMaxLineWidth, lineWidth);
      }
    }

    newMaxLineWidth += lineNumberWidth;

    if (newMaxLineWidth != _cachedMaxLineWidth) {
      setState(() {
        maxLineWidth = newMaxLineWidth;
        _cachedMaxLineWidth = newMaxLineWidth - lineNumberWidth;
      });
    }
  }

  void _updateSelection(DragStartDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    _selectionAnchor = position;
    setState(() {
      if (_selectionMode == SelectionMode.word) {
        _selectWordAtPosition(position);
        _selectionAnchor = editingCore.selectionStart;
      } else if (_selectionMode == SelectionMode.line) {
        _selectLineAtPosition(position);
        _selectionAnchor = editingCore.selectionStart;
      } else {
        editingCore.setSelection(position, position);
      }
    });
  }

  void _updateSelectionOnDrag(DragUpdateDetails details) {
    final position = getPositionFromOffset(details.localPosition);
    setState(() {
      if (_selectionMode == SelectionMode.word) {
        _extendSelectionByWordFromAnchor(_selectionAnchor!, position);
      } else if (_selectionMode == SelectionMode.line) {
        _extendSelectionByLineFromAnchor(_selectionAnchor!, position);
      } else {
        editingCore.setSelection(_selectionAnchor!, position);
      }
    });
    autoScrollOnDrag(details.localPosition);
  }
}
