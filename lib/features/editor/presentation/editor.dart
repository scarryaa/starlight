import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide TabBar, Tab;
import 'package:flutter/scheduler.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/presentation/editor_painter.dart';
import 'package:starlight/features/editor/presentation/line_numbers.dart';
import 'package:starlight/features/editor/services/calculation_service.dart';
import 'package:starlight/features/editor/services/clipboard_service.dart';
import 'package:starlight/features/editor/services/editor_service.dart';
import 'package:starlight/features/editor/services/gesture_handling_service.dart';
import 'package:starlight/features/editor/services/keyboard_handler_service.dart';
import 'package:starlight/features/editor/services/layout_service.dart';
import 'package:starlight/features/editor/services/scroll_service.dart';
import 'package:starlight/features/editor/services/selection_service.dart';
import 'package:starlight/features/editor/services/syntax_highlighter.dart';
import 'package:starlight/features/editor/services/text_editing_service.dart';
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

class CodeEditorState extends State<CodeEditor> {
  late TextEditingCore editingCore;
  late TextEditingService textEditingService;
  late CodeEditorSelectionService selectionService;
  late LayoutService layoutService;
  late CodeEditorService editorService;
  late GestureHandlingService gestureHandlingService;
  late KeyboardHandlingService keyboardHandlingService;
  late ClipboardService clipboardService;

  int firstVisibleLine = 0;
  int visibleLineCount = 500;
  double maxLineWidth = 0.0;
  double zoomLevel = 1.0;
  double lineNumberWidth = 0.0;

  late TextPainter _textPainter;
  late SyntaxHighlighter _syntaxHighlighter;
  int _lastKnownVersion = -1;

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

    editingCore = TextEditingCore("\n");
    editingCore.setText(widget.initialCode);
    if (widget.initialCode.isEmpty) {
      editingCore.handleBackspace();
    }
    editingCore.addListener(_onTextChanged);
    textEditingService = TextEditingService(editingCore);

    selectionService = CodeEditorSelectionService(
      editingCore: editingCore,
      getPositionFromOffset: (Offset offset) => 0,
      autoScrollOnDrag: (Offset offset, Size size) {},
    );

    final scrollService = CodeEditorScrollService(
      editingCore: editingCore,
      zoomLevel: widget.zoomLevel,
      lineNumberWidth: lineNumberWidth,
    );

    clipboardService = ClipboardService(textEditingService);

    keyboardHandlingService = KeyboardHandlingService(
        textEditingService: textEditingService,
        clipboardService: clipboardService,
        recalculateEditor: _recalculateEditor,
        keyboardShortcutService: widget.keyboardShortcutService);

    editorService = CodeEditorService(
      scrollService: scrollService,
      selectionService: selectionService,
      keyboardHandlerService: keyboardHandlingService,
      clipboardService: ClipboardService(textEditingService),
      calculationService: CodeEditorCalculationService(),
    );

    layoutService = LayoutService(editingCore);

    gestureHandlingService = GestureHandlingService(
        textEditingService: textEditingService,
        selectionService: selectionService,
        getPositionFromOffset: editorService.getPositionFromOffset,
        recalculateEditor: _recalculateEditor);

    clipboardService = ClipboardService(textEditingService);
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

    layoutService = LayoutService(editingCore);

    scrollService.lineNumberWidth = layoutService.calculateLineNumberWidth();

    selectionService.getPositionFromOffset =
        editorService.getPositionFromOffset;
    selectionService.autoScrollOnDrag = scrollService.autoScrollOnDrag;

    editorService.initialize(editingCore, widget.zoomLevel);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateEditor();
    });
  }

  Widget _buildCodeArea(BoxConstraints constraints) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: _handleTap,
      onPanStart: selectionService.updateSelection,
      onPanUpdate: (details) =>
          selectionService.updateSelectionOnDrag(details, constraints.biggest),
      onPanEnd: (details) {},
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
                    controller:
                        editorService.scrollService.codeScrollController,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      controller:
                          editorService.scrollService.codeScrollController,
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller:
                              editorService.scrollService.horizontalController,
                          child: SizedBox(
                            width: max(layoutService.getMaxLineWidth(),
                                constraints.maxWidth),
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
                                lineNumberWidth:
                                    editorService.scrollService.lineNumberWidth,
                                viewportWidth: constraints.maxWidth,
                                version: editingCore.version,
                                editingCore: editingCore,
                                firstVisibleLine: firstVisibleLine,
                                visibleLineCount: visibleLineCount,
                                horizontalOffset: editorService.scrollService
                                        .horizontalController.hasClients
                                    ? editorService.scrollService
                                        .horizontalController.offset
                                        .clamp(
                                            0.0,
                                            editorService
                                                .scrollService
                                                .horizontalController
                                                .position
                                                .maxScrollExtent)
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
                        controller: editorService
                            .scrollService.horizontalScrollbarController,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: editorService
                              .scrollService.horizontalScrollbarController,
                          child: SizedBox(
                            width: max(layoutService.getMaxLineWidth(),
                                constraints.maxWidth),
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
    final scaledLineNumberWidth =
        editorService.scrollService.lineNumberWidth * widget.zoomLevel;
    final scaledLineHeight = CodeEditorConstants.lineHeight * widget.zoomLevel;

    return SizedBox(
      width: scaledLineNumberWidth,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: editorService.scrollService.lineNumberScrollController,
          child: SizedBox(
            height: max(editingCore.lineCount * scaledLineHeight,
                constraints.maxHeight),
            child: LineNumbers(
              lineCount: editingCore.lineCount,
              lineHeight: CodeEditorConstants.lineHeight,
              lineNumberWidth: editorService.scrollService.lineNumberWidth,
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

  void _handleTap(TapDownDetails details) {
    gestureHandlingService.handleTap(details);
    widget.focusNode.requestFocus();
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (keyboardHandlingService.handleKeyPress(event)) {
      editorService.scrollService.ensureCursorVisibility();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
          editorService.scrollService.resetAllScrollPositions();
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
    layoutService.calculateLineNumberWidth();
    layoutService.updateMaxLineWidth();
    editorService.scrollService.updateVisibleLines();
    editorService.scrollService.ensureCursorVisibility();
    setState(() {});
  }
}
