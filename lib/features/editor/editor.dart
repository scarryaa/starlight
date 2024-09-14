import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:starlight/features/editor/editor_painter.dart';
import 'package:starlight/features/editor/line_numbers.dart';
import 'package:starlight/features/editor/models/text_editing_core.dart';

class CodeEditor extends StatefulWidget {
  final String initialCode;
  final String filePath;
  final Function(bool) onModified;
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

  const CodeEditor({
    super.key,
    required this.initialCode,
    required this.filePath,
    required this.onModified,
    required this.matchPositions,
    required this.searchTerm,
    required this.currentMatchIndex,
    required this.onSelectPreviousMatch,
    required this.onSelectNextMatch,
    required this.onReplace,
    required this.onReplaceAll,
    required this.onUpdateSearchTerm,
    required this.onUpdateReplaceTerm,
    this.selectionStart,
    this.selectionEnd,
    this.cursorPosition,
  });

  @override
  _CodeEditorState createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  static const double lineHeight = 24.0;
  static double charWidth = 8.0;
  static const double scrollbarWidth = 10.0;
  late TextEditingCore editingCore;
  bool _isModified = false;
  late ScrollController codeScrollController;
  late ScrollController lineNumberScrollController;

  late ScrollController horizontalController;
  late ScrollController horizontalScrollbarController;
  final FocusNode focusNode = FocusNode();

  bool _scrollingCode = false;
  bool _scrollingLineNumbers = false;
  bool _isHorizontalScrolling = false;
  int firstVisibleLine = 0;
  int visibleLineCount = 0;
  double maxLineWidth = 0.0;
  double lineNumberWidth = 0.0;
  final Map<int, double> _lineWidthCache = {};

  int _lastCalculatedLine = -1;
  double _cachedMaxLineWidth = 0;
  int _lastLineCount = 0;
  late TextPainter _textPainter;
  int _lastKnownVersion = -1;

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
    codeScrollController.dispose();
    horizontalController.dispose();
    lineNumberScrollController.dispose();
    focusNode.dispose();
    _textPainter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    try {
      // Again, dumb way to avoid formatting bug when initializing rope for now
      // TODO fix this
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

    codeScrollController = ScrollController()..addListener(_onCodeScroll);

    lineNumberScrollController = ScrollController()
      ..addListener(_onLineNumberScroll);

    horizontalController = ScrollController()..addListener(_onHorizontalScroll);

    horizontalScrollbarController = ScrollController()
      ..addListener(_syncHorizontalScrollbar);

    _calculateLineNumberWidth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMaxLineWidth();
      _updateVisibleLines();
    });
  }

  void _autoScrollOnDrag(Offset position) {
    const scrollThreshold = 50.0;
    const scrollStep = 16.0;

    if (position.dy < scrollThreshold && codeScrollController.offset > 0) {
      codeScrollController
          .jumpTo(max(0, codeScrollController.offset - scrollStep));
    } else if (position.dy > context.size!.height - scrollThreshold &&
        codeScrollController.offset <
            codeScrollController.position.maxScrollExtent) {
      codeScrollController.jumpTo(min(
          codeScrollController.position.maxScrollExtent,
          codeScrollController.offset + scrollStep));
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

  Widget _buildCodeArea(BoxConstraints constraints) {
    final theme = Theme.of(context);

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
                      controller: codeScrollController,
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: horizontalController,
                          child: SizedBox(
                            width: max(maxLineWidth, constraints.maxWidth),
                            height: max(editingCore.lineCount * lineHeight,
                                constraints.maxHeight),
                            child: CustomPaint(
                              painter: CodeEditorPainter(
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
                      width: scrollbarWidth + 2,
                      height: scrollbarWidth,
                      child: ColoredBox(color: theme.colorScheme.surface),
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

  Widget _buildLineNumbers(BoxConstraints constraints) {
    final theme = Theme.of(context);

    return SizedBox(
        width: lineNumberWidth,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            controller: lineNumberScrollController,
            child: SizedBox(
              height: max(
                  editingCore.lineCount * lineHeight, constraints.maxHeight),
              child: LineNumbers(
                lineCount: editingCore.lineCount,
                lineHeight: lineHeight,
                lineNumberWidth: lineNumberWidth,
                firstVisibleLine: firstVisibleLine,
                visibleLineCount: visibleLineCount,
                textStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
          ),
        ));
  }

  void _calculateLineNumberWidth() {
    final lineCount = editingCore.lineCount;
    final maxLineNumberWidth = '$lineCount'.length * charWidth;
    lineNumberWidth = maxLineNumberWidth + 40;
  }

  double _calculateLineWidth(String line) {
    return line.length * charWidth;
  }

  void _ensureCursorVisibility() {
    if (!codeScrollController.hasClients || !horizontalController.hasClients) {
      return;
    }

    final cursorPosition =
        editingCore.cursorPosition.clamp(0, editingCore.length);
    int cursorLine = editingCore.rope.findLine(cursorPosition);
    int lineStartIndex = editingCore.getLineStartIndex(cursorLine);
    int cursorColumn = cursorPosition - lineStartIndex;

    // Vertical scrolling
    final cursorY = cursorLine * lineHeight;
    if (cursorY < codeScrollController.offset) {
      codeScrollController.jumpTo(cursorY);
    } else if (cursorY >
        codeScrollController.offset +
            codeScrollController.position.viewportDimension -
            lineHeight) {
      codeScrollController.jumpTo(cursorY -
          codeScrollController.position.viewportDimension +
          lineHeight);
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

    // Ensure the entire selection is visible
    if (editingCore.hasSelection()) {
      final selectionStart = editingCore.selectionStart!;
      final selectionEnd = editingCore.selectionEnd!;
      final startLine = editingCore.rope.findLine(selectionStart);
      final endLine = editingCore.rope.findLine(selectionEnd);
      final startColumn =
          selectionStart - editingCore.getLineStartIndex(startLine);
      final endColumn = selectionEnd - editingCore.getLineStartIndex(endLine);

      // Vertical scrolling for selection
      final startY = startLine * lineHeight;
      final endY = (endLine + 1) * lineHeight;
      if (startY < codeScrollController.offset) {
        codeScrollController.jumpTo(startY);
      } else if (endY >
          codeScrollController.offset +
              codeScrollController.position.viewportDimension) {
        codeScrollController
            .jumpTo(endY - codeScrollController.position.viewportDimension);
      }

      // Horizontal scrolling for selection
      final startX = startColumn * charWidth + lineNumberWidth;
      final endX = endColumn * charWidth + lineNumberWidth;
      if (startX < horizontalController.offset + lineNumberWidth) {
        horizontalController.jumpTo(startX - lineNumberWidth);
      } else if (endX >
          horizontalController.offset +
              horizontalController.position.viewportDimension) {
        horizontalController.jumpTo(
            endX - horizontalController.position.viewportDimension + charWidth);
      }
    }
  }

  int _getPositionFromOffset(Offset offset) {
    final adjustedOffset = offset +
        Offset(
            max(0, horizontalController.offset), codeScrollController.offset);
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

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final bool isControlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;
    final bool isMetaPressed = HardwareKeyboard.instance.isMetaPressed;

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

    // Only ensure cursor visibility if no modifier keys are pressed
    if (!isShiftPressed &&
        !isAltPressed &&
        !isMetaPressed &&
        !isControlPressed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureCursorVisibility();
      });
    }

    return KeyEventResult.handled;
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

  void _handleTap(TapDownDetails details) {
    final position = _getPositionFromOffset(details.localPosition);
    setState(() {
      editingCore.cursorPosition = position;
      editingCore.clearSelection();
    });
    focusNode.requestFocus();
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
    charWidth = _textPainter.width;
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
          _isModified = false;
        });
        widget.onModified(_isModified);

        SchedulerBinding.instance.addPostFrameCallback((_) {
          setState(() {
            if (codeScrollController.hasClients) {
              codeScrollController.jumpTo(0);
            }
            if (lineNumberScrollController.hasClients) {
              lineNumberScrollController.jumpTo(0);
            }
            if (horizontalController.hasClients) {
              horizontalController.jumpTo(0);
            }
            if (horizontalScrollbarController.hasClients) {
              horizontalScrollbarController.jumpTo(0);
            }
          });
          _recalculateEditor();
        });
      } catch (e, stackTrace) {
        print('Error loading file: $e');
        print("Stack trace: $stackTrace");
      }
    }
  }

  void _onCodeScroll() {
    if (!_scrollingCode && !_scrollingLineNumbers) {
      _scrollingCode = true;
      lineNumberScrollController.jumpTo(codeScrollController.offset);
      _scrollingCode = false;
    }
    _updateVisibleLines();
    setState(() {});
  }

  void _onHorizontalScroll() {
    if (!_isHorizontalScrolling &&
        horizontalController.hasClients &&
        horizontalScrollbarController.hasClients) {
      _isHorizontalScrolling = true;
      horizontalScrollbarController.jumpTo(horizontalController.offset);
      _isHorizontalScrolling = false;
    }
    setState(() {});
  }

  void _onLineNumberScroll() {
    if (!_scrollingLineNumbers && !_scrollingCode) {
      _scrollingLineNumbers = true;
      codeScrollController.jumpTo(lineNumberScrollController.offset);
      _scrollingLineNumbers = false;
    }
    _updateVisibleLines();
    setState(() {});
  }

  void _onTextChanged() {
    if (_lastKnownVersion != editingCore.version) {
      setState(() {
        _isModified = true;
      });
      widget.onModified(_isModified);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalculateEditor();
      });
      _lastKnownVersion = editingCore.version;
    }
  }

  void _recalculateEditor() {
    _calculateLineNumberWidth();
    _updateMaxLineWidth();
    _updateVisibleLines();
    _ensureCursorVisibility();
    setState(() {});
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

  void _updateVisibleLines() {
    if (!mounted || !codeScrollController.hasClients) return;

    final totalLines = editingCore.lineCount;
    final viewportHeight = codeScrollController.position.viewportDimension;

    firstVisibleLine = (codeScrollController.offset / lineHeight)
        .floor()
        .clamp(0, totalLines == 0 ? 0 : totalLines - 1);
    visibleLineCount = (viewportHeight / lineHeight).ceil() + 1;

    if (firstVisibleLine + visibleLineCount > totalLines) {
      visibleLineCount = totalLines - firstVisibleLine;
    }
  }
}
