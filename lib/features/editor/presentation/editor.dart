import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide TabBar, Tab;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/completions_widget/completions_widget.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/presentation/editor_painter.dart';
import 'package:starlight/features/editor/presentation/line_numbers.dart';
import 'package:starlight/features/editor/services/calculation_service.dart';
import 'package:starlight/features/editor/services/clipboard_service.dart';
import 'package:starlight/features/editor/services/editor_service.dart';
import 'package:starlight/features/editor/services/gesture_handling_service.dart';
import 'package:starlight/features/editor/services/keyboard_handler_service.dart';
import 'package:starlight/features/editor/services/layout_service.dart';
import 'package:starlight/features/editor/services/lsp_client.dart';
import 'package:starlight/features/editor/services/scroll_service.dart';
import 'package:starlight/features/editor/services/selection_service.dart';
import 'package:starlight/features/editor/services/syntax_highlighter.dart';
import 'package:starlight/features/editor/services/text_editing_service.dart';
import 'package:starlight/services/keyboard_shortcut_service.dart';
import 'package:starlight/services/settings_service.dart';
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
  final Function(Function(double))? onZoomChanged;
  double zoomLevel;

  CodeEditor({
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
    this.onZoomChanged,
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
  late SettingsService _settingsService;
  late LspClient _lspClient;
  List<CompletionItem> _completions = [];
  CompletionsWidget? _completionsWidget;
  OverlayEntry? _completionsOverlay;

  int firstVisibleLine = 0;
  int visibleLineCount = 800;
  double maxLineWidth = 0.0;
  double zoomLevel = 1.0;
  double lineNumberWidth = 0.0;

  late TextPainter _textPainter;
  late SyntaxHighlighter _syntaxHighlighter;
  int _lastKnownVersion = -1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your existing code editor widget
        LayoutBuilder(
          builder: (context, constraints) {
            return ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
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
        ),
      ],
    );
  }

  void _applyCompletion(CompletionItem completion) {
    print("Applying completion: ${completion.label}");
    final cursorPosition = editingCore.cursorPosition;
    final line = _getLineForPosition(cursorPosition);
    final lineStartIndex = editingCore.getLineStartIndex(line);
    final lineEndIndex = editingCore.getLineEndIndex(line);
    final lineText =
        editingCore.getText().substring(lineStartIndex, lineEndIndex);

    print("Current line text: '$lineText'");
    print("Cursor position: $cursorPosition");

    // Find the start of the word being completed
    int wordStart = cursorPosition - lineStartIndex;
    while (wordStart > 0 &&
        RegExp(r'[a-zA-Z0-9_]').hasMatch(lineText[wordStart - 1])) {
      wordStart--;
    }

    // Calculate the range to be replaced
    final startPosition = lineStartIndex + wordStart;
    final endPosition = cursorPosition;

    print("Start position: $startPosition");
    print("End position: $endPosition");

    // Get the text to be inserted
    final insertText = completion.insertText ?? completion.label;
    print("Text to be inserted: '$insertText'");

    // Replace the text
    editingCore.replaceRange(startPosition, endPosition, insertText);

    // Ensure the changes are reflected
    setState(() {});

    // Hide the completions list
    _hideCompletionsList();

    // Ensure the cursor is visible after applying the completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editorService.scrollService.ensureCursorVisibility();
    });

    // Notify the LSP server of the change
    _sendDocumentChanges();

    print("Completion applied. New text: '${editingCore.getText()}'");
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
    if (widget.zoomLevel != oldWidget.zoomLevel) {
      _updateVisibleLineCount();
    }
  }

  @override
  void dispose() {
    editingCore.removeListener(_onTextChanged);
    editingCore.dispose();
    _textPainter.dispose();
    _settingsService.removeListener(_onSettingsChanged);
    _lspClient.stop();
    super.dispose();
  }

  void _onSettingsChanged() {
    _syntaxHighlighter.updateTheme(_settingsService.themeMode, context);
    setState(() {});
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

    _settingsService = Provider.of<SettingsService>(context, listen: false);
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
    _syntaxHighlighter = SyntaxHighlighter(
      {
        'keyword': const TextStyle(
          color: Colors.blue,
        ),
        'type': const TextStyle(color: Colors.green),
        'comment': const TextStyle(
          color: Colors.grey,
        ),
        'string': const TextStyle(color: Colors.red),
        'number': const TextStyle(color: Colors.purple),
        'function': const TextStyle(color: Colors.orange),
        'default': TextStyle(color: _getDefaultTextColor(context)),
      },
      language: 'dart',
      initialThemeMode: _settingsService.themeMode,
    );

    layoutService = LayoutService(editingCore);

    scrollService.lineNumberWidth = layoutService.calculateLineNumberWidth();

    selectionService.getPositionFromOffset =
        editorService.getPositionFromOffset;
    selectionService.autoScrollOnDrag = scrollService.autoScrollOnDrag;

    editorService.initialize(editingCore, widget.zoomLevel);

    _settingsService.addListener(_onSettingsChanged);
    editorService.scrollService.visibleLineCount = 800;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculateEditor();
      _updateVisibleLineCount();
      editorService.scrollService.visibleLineCount = visibleLineCount;
    });
    widget.onZoomChanged?.call(_recalculateEditorAfterZoom);
    _initializeLspClient();
  }

  Future<void> _initializeLspClient() async {
    _lspClient = LspClient();

    const dartCommand = '/Users/scarlet/flutter/bin/dart';
    final arguments = ['language-server', '--protocol=lsp'];

    try {
      await _lspClient.start(dartCommand, arguments);

      // Send the initialized notification
      await _lspClient.sendRequest('initialized', {});

      // Open the document
      await _lspClient.sendRequest('textDocument/didOpen', {
        'textDocument': {
          'uri': 'file://${widget.filePath}',
          'languageId': 'dart',
          'version': 1,
          'text': editingCore.getText()
        }
      });

      print("LSP server initialized successfully");
    } catch (e) {
      print("Error initializing LSP client: $e");
    }
  }

  void maintainFocus() {
    widget.focusNode.requestFocus();
  }

  Widget _buildCodeArea(BoxConstraints constraints) {
    final theme = Theme.of(context);
    final defaultTextColor = _getDefaultTextColor(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        _handleScroll(notification);
        return true;
      },
      child: GestureDetector(
          onTapDown: _handleTap,
          onPanStart: (details) {
            selectionService.updateSelection(details);
            _recalculateEditor();
          },
          onPanUpdate: (details) {
            selectionService.updateSelectionOnDrag(
                details, constraints.biggest);
            _recalculateEditor();
          },
          onPanEnd: (details) {},
          behavior: HitTestBehavior.deferToChild,
          child: Focus(
            focusNode: widget.focusNode,
            onKeyEvent: _handleKeyPress,
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  theme.colorScheme.secondary.withOpacity(0.6),
                ),
                radius: Radius.zero,
              ),
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
                              controller: editorService
                                  .scrollService.horizontalController,
                              child: SizedBox(
                                width: max(layoutService.getMaxLineWidth(),
                                    constraints.maxWidth),
                                height: max(
                                        editingCore.lineCount *
                                            CodeEditorConstants.lineHeight,
                                        constraints.maxHeight) +
                                    100,
                                child: CustomPaint(
                                  painter: CodeEditorPainter(
                                    viewportHeight: editorService
                                            .scrollService.visibleLineCount *
                                        CodeEditorConstants.lineHeight,
                                    syntaxHighlighter: _syntaxHighlighter,
                                    zoomLevel: widget.zoomLevel,
                                    matchPositions: widget.matchPositions,
                                    searchTerm: widget.searchTerm,
                                    highlightColor: theme.colorScheme.secondary
                                        .withOpacity(0.3),
                                    lineNumberWidth: editorService
                                        .scrollService.lineNumberWidth,
                                    viewportWidth: constraints.maxWidth,
                                    version: editingCore.version,
                                    editingCore: editingCore,
                                    firstVisibleLine: firstVisibleLine,
                                    visibleLineCount: visibleLineCount,
                                    horizontalOffset: editorService
                                            .scrollService
                                            .horizontalController
                                            .hasClients
                                        ? editorService.scrollService
                                            .horizontalController.offset
                                            .clamp(
                                            0.0,
                                            editorService
                                                .scrollService
                                                .horizontalController
                                                .position
                                                .maxScrollExtent,
                                          )
                                        : 0,
                                    textStyle:
                                        theme.textTheme.bodyMedium!.copyWith(
                                      fontFamily: 'SF Mono',
                                      color: defaultTextColor,
                                    ),
                                    selectionColor: theme.colorScheme.primary
                                        .withOpacity(0.3),
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
          )),
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
                    constraints.maxHeight) +
                100,
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

  Color _getDefaultTextColor(BuildContext context) {
    final brightness = _settingsService.themeMode == ThemeMode.system
        ? MediaQuery.of(context).platformBrightness
        : _settingsService.themeMode == ThemeMode.dark
            ? Brightness.dark
            : Brightness.light;

    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space &&
          HardwareKeyboard.instance.isControlPressed) {
        _showCompletionsList();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _hideCompletionsList();
        return KeyEventResult.handled;
      }

      // Handle regular typing and other key events
      if (keyboardHandlingService.handleKeyPress(event)) {
        editorService.scrollService.ensureCursorVisibility();
        _hideCompletionsList(); // Hide completions when typing
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _showCompletionsList() async {
    final cursorPosition = editingCore.cursorPosition;
    final line = _getLineForPosition(cursorPosition);
    final lineStartIndex = editingCore.getLineStartIndex(line);
    final character = cursorPosition - lineStartIndex;

    try {
      _completions = await getCompletions(line, character);
    } catch (e) {
      print("Error fetching completions: $e");
      _completions = _getFallbackCompletions();
    }

    if (_completions.isNotEmpty) {
      final position = _calculateCompletionPosition(line, character);
      _showCompletionsOverlay(position);
    } else {
      print("No completions available");
    }
  }

  void _showCompletionsOverlay(Offset position) {
    _completionsOverlay?.remove();
    _completionsOverlay = OverlayEntry(
      builder: (context) => CompletionsWidget(
        completions: _completions,
        onSelected: _applyCompletion,
        position: position,
        editorFocusNode: widget.focusNode,
        onDismiss: _hideCompletionsList,
      ),
    );
    Overlay.of(context).insert(_completionsOverlay!);
  }

  Offset _calculateCompletionPosition(int line, int character) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final editorOffset = renderBox.localToGlobal(Offset.zero);
      final scrollOffset =
          editorService.scrollService.codeScrollController.offset;
      final horizontalScrollOffset =
          editorService.scrollService.horizontalController.offset;

      // Calculate the position considering the scroll offsets
      final cursorX =
          (character * CodeEditorConstants.charWidth * widget.zoomLevel) -
              horizontalScrollOffset +
              editorService.scrollService.lineNumberWidth * widget.zoomLevel;
      final cursorY =
          (line * CodeEditorConstants.lineHeight * widget.zoomLevel) -
              scrollOffset;

      return Offset(
        editorOffset.dx + cursorX,
        editorOffset.dy +
            cursorY +
            CodeEditorConstants.lineHeight * widget.zoomLevel,
      );
    }

    print("RenderBox is null, cannot calculate completion position");
    return Offset.zero;
  }

  void _hideCompletionsList() {
    _completionsOverlay?.remove();
    _completionsOverlay = null;
  }

  List<CompletionItem> _getFallbackCompletions() {
    return [
      CompletionItem(label: "if", detail: "if statement"),
      CompletionItem(label: "for", detail: "for loop"),
      CompletionItem(label: "while", detail: "while loop"),
      CompletionItem(label: "class", detail: "class definition"),
      CompletionItem(label: "function", detail: "function definition"),
    ];
  }

  int _getLineForPosition(int position) {
    int line = 0;
    int currentPosition = 0;
    while (currentPosition < position && line < editingCore.lineCount) {
      currentPosition = editingCore.getLineEndIndex(line) + 1;
      if (currentPosition <= position) {
        line++;
      }
    }
    return line;
  }

  void _replaceText(int start, int end, String replacement) {
    editingCore.replaceRange(start, end, replacement);
    editingCore.cursorPosition = start + replacement.length;
    editingCore.clearSelection();
    editingCore.incrementVersion();
    editingCore.checkModificationStatus();
    setState(() {});
  }

  void _handleTap(TapDownDetails details) {
    gestureHandlingService.handleTap(details);
    widget.focusNode.requestFocus();
  }

  void _initializeTextPainter(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'X',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'SF Mono',
          color: defaultTextColor,
        ),
      ),
    );
    _textPainter.layout();
    CodeEditorConstants.charWidth = _textPainter.width;
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
    print("Text changed. New version: ${editingCore.version}");
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
      _sendDocumentChanges();
    }
  }

  void _sendDocumentChanges() {
    _lspClient.sendRequest('textDocument/didChange', {
      'textDocument': {
        'uri': 'file://${widget.filePath}',
        'version': editingCore.version,
      },
      'contentChanges': [
        {'text': editingCore.getText()}
      ]
    });
  }

  Future<List<CompletionItem>> getCompletions(int line, int character) async {
    try {
      final response = await _lspClient.sendRequest('textDocument/completion', {
        'textDocument': {'uri': 'file://${widget.filePath}'},
        'position': {'line': line, 'character': character},
      }).timeout(const Duration(seconds: 5)); // Add a 5-second timeout

      final items = response['result']['items'] as List<dynamic>;
      return items.map((item) => CompletionItem.fromJson(item)).toList();
    } catch (e) {
      print("Error getting completions: $e");
      return _getFallbackCompletions();
    }
  }

  void updateZoomLevel(double newZoomLevel) {
    setState(() {
      widget.zoomLevel = newZoomLevel;
      editorService.scrollService.zoomLevel = newZoomLevel;
      editorService.calculationService.zoomLevel = newZoomLevel;
    });

    // Recalculate layout
    layoutService.calculateLineNumberWidth();
    layoutService.updateMaxLineWidth();

    // Update visible line count
    _updateVisibleLineCount();

    // Ensure cursor visibility after zoom
    editorService.scrollService.ensureCursorVisibility();

    // Force a repaint
    _recalculateEditor();
  }

  bool _handleScroll(ScrollNotification notification) {
    _recalculateVisibleLines();
    return true;
  }

  void _recalculateEditor() {
    layoutService.calculateLineNumberWidth();
    layoutService.updateMaxLineWidth();
    editorService.scrollService.updateVisibleLines();
    editorService.scrollService.ensureCursorVisibility();
    _syntaxHighlighter.invalidateCache();
    _updateVisibleLineCount();
    setState(() {});
  }

  void _recalculateVisibleLines() {
    if (editorService.scrollService.codeScrollController.hasClients) {
      final scrollPosition =
          editorService.scrollService.codeScrollController.position;

      firstVisibleLine = (scrollPosition.pixels /
              (CodeEditorConstants.lineHeight * widget.zoomLevel))
          .floor();

      _updateVisibleLineCount();

      // Ensure we don't go out of bounds
      firstVisibleLine = max(0, firstVisibleLine);
      visibleLineCount =
          min(visibleLineCount, editingCore.lineCount - firstVisibleLine);

      setState(() {});
    }
  }

  void _updateVisibleLineCount() {
    if (editorService.scrollService.codeScrollController.hasClients) {
      final viewportHeight = editorService
          .scrollService.codeScrollController.position.viewportDimension;
      visibleLineCount =
          (viewportHeight / (CodeEditorConstants.lineHeight * widget.zoomLevel))
                  .ceil() +
              1;
      setState(() {});
    }
  }

  void _recalculateEditorAfterZoom(double zoomLevel) {
    setState(() {
      // Update zoomLevel in necessary services
      editorService.scrollService.zoomLevel = zoomLevel;
      editorService.calculationService.zoomLevel = zoomLevel;

      // Recalculate layout
      layoutService.calculateLineNumberWidth();
      layoutService.updateMaxLineWidth();

      // Update visible line count
      _updateVisibleLineCount();

      // Ensure cursor visibility after zoom
      editorService.scrollService.ensureCursorVisibility();
    });
  }
}
