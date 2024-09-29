import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' hide TabBar, Tab;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:starlight/features/editor/completions_widget/completions_widget.dart';
import 'package:starlight/features/editor/domain/models/folding_region.dart';
import 'package:starlight/features/editor/domain/models/text_editing_core.dart';
import 'package:starlight/features/editor/minimap/minimap.dart';
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
  late ScrollController _completionsScrollController;
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
  List<FoldingRegion> foldingRegions = [];
  int _lastCompletionPosition = -1;
  bool _isBackspacing = false;
  final bool _shortcutHandled = false;
  Timer? _suggestionsTimer;
  bool _showingSuggestions = false;
  int _selectedSuggestionIndex = 0;
  String _currentWord = '';
  late final List<String> _dartKeywords = [
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'get',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'library',
    'mixin',
    'new',
    'null',
    'operator',
    'part',
    'rethrow',
    'return',
    'set',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield'
  ];
  ScrollController lineNumberScrollController = ScrollController();
  late ValueNotifier<bool> repaintNotifier;

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
        if (_showingSuggestions)
          CompletionsWidget(
            completions: _completions,
            onSelected: _applyCompletion,
            position: _calculateCompletionPosition(
              _getLineForPosition(editingCore.cursorPosition),
              _getCharacterForPosition(editingCore.cursorPosition),
            ),
            selectedIndex: _selectedSuggestionIndex,
            scrollController: _completionsScrollController,
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath) {
      _lspClient.stop();
      _initializeLspClient();
    }

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
    _suggestionsTimer?.cancel();
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

    repaintNotifier = ValueNotifier<bool>(false);

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

    _initializeLspClient().then((_) {
      if (mounted) {
        setState(() {
          _syntaxHighlighter = SyntaxHighlighter(
            language: 'dart',
            initialThemeMode: _settingsService.themeMode,
            lspClient: _lspClient,
          );
          _syntaxHighlighter.updateStyles(context);
        });
        _updateSemanticTokens();
      }
    });

    final scrollService = CodeEditorScrollService(
      editingCore: editingCore,
      zoomLevel: widget.zoomLevel,
      lineNumberWidth: lineNumberWidth,
    );

    clipboardService = ClipboardService(textEditingService);

    _completionsScrollController = ScrollController();
    keyboardHandlingService = KeyboardHandlingService(
      textEditingService: textEditingService,
      clipboardService: clipboardService,
      recalculateEditor: _recalculateEditor,
      keyboardShortcutService: widget.keyboardShortcutService,
    );

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
      recalculateEditor: _recalculateEditor,
    );

    clipboardService = ClipboardService(textEditingService);
    _syntaxHighlighter = SyntaxHighlighter(
      language: 'dart',
      initialThemeMode: _settingsService.themeMode,
      lspClient: _lspClient,
    );
    _syntaxHighlighter.updateStyles(context);
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

    repaintNotifier.addListener(() {
      setState(() {});
    });

    widget.onZoomChanged?.call(_recalculateEditorAfterZoom);
    editingCore.addListener(_onTextChangedForSuggestions);
    _updateFoldingRegions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSemanticTokens();
      _initializeAfterBuild(context);
    });
  }

  void _initializeAfterBuild(BuildContext context) {
    _initializeTextPainter(context);
    _settingsService = Provider.of<SettingsService>(context, listen: false);

    // Trigger a rebuild
    setState(() {});
  }

  Future<void> _initializeLspClient() async {
    _lspClient = LspClient();

    const dartCommand = '/Users/scarlet/flutter/bin/dart';
    final arguments = ['language-server', '--protocol=lsp'];

    try {
      await _lspClient.start(dartCommand, arguments);
      await _lspClient
          .initialized; // Wait for the client to be fully initialized

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
      child: Row(
        children: [
          Expanded(
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
                            controller: editorService
                                .scrollService.codeScrollController,
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              controller: editorService
                                  .scrollService.codeScrollController,
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
                                        foldingRegions: foldingRegions,
                                        viewportHeight: editorService
                                                .scrollService
                                                .visibleLineCount *
                                            CodeEditorConstants.lineHeight,
                                        syntaxHighlighter: _syntaxHighlighter,
                                        zoomLevel: widget.zoomLevel,
                                        matchPositions: widget.matchPositions,
                                        searchTerm: widget.searchTerm,
                                        highlightColor: theme
                                            .colorScheme.secondary
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
                                        textStyle: theme.textTheme.bodyMedium!
                                            .copyWith(
                                          fontFamily: 'SF Mono',
                                          color: defaultTextColor,
                                        ),
                                        selectionColor: theme
                                            .colorScheme.primary
                                            .withOpacity(0.3),
                                        cursorColor: theme.colorScheme.primary,
                                        cursorPosition:
                                            editingCore.cursorPosition,
                                        selectionStart:
                                            editingCore.selectionStart,
                                        selectionEnd: editingCore.selectionEnd,
                                        repaintNotifier: repaintNotifier,
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
                              child:
                                  ColoredBox(color: theme.colorScheme.surface),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              height: CodeEditorConstants.scrollbarWidth,
                              child: Scrollbar(
                                controller: editorService.scrollService
                                    .horizontalScrollbarController,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: editorService.scrollService
                                      .horizontalScrollbarController,
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
            ),
          ),
          Minimap(
            editingCore: editingCore,
            syntaxHighlighter: _syntaxHighlighter,
            scrollController: editorService.scrollService.codeScrollController,
            viewportHeight: constraints.maxHeight,
            editorHeight: editingCore.lineCount *
                CodeEditorConstants.lineHeight *
                widget.zoomLevel,
            zoomLevel: widget.zoomLevel,
          ),
        ],
      ),
    );
  }

  void _updateFoldingRegions() {
    foldingRegions.clear();
    final lines = editingCore.getText().split('\n');
    final stack = <FoldingStackItem>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      int openBraces = '{'.allMatches(line).length;
      int closeBraces = '}'.allMatches(line).length;

      for (int j = 0; j < openBraces; j++) {
        stack.add(FoldingStackItem(i, line.indexOf('{', j)));
      }

      for (int j = 0; j < closeBraces; j++) {
        if (stack.isNotEmpty) {
          final startItem = stack.removeLast();
          if (i > startItem.line) {
            foldingRegions.add(FoldingRegion(
              startLine: startItem.line,
              endLine: i,
              startColumn: startItem.column,
              endColumn: line.indexOf('}', j),
              isFolded: false,
              isHidden: false,
            ));
          }
        }
      }
    }

    foldingRegions.sort((a, b) => a.startLine.compareTo(b.startLine));

    _updateVisibleLineCount();
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
              scrollController: lineNumberScrollController,
              lineCount: editingCore.lineCount,
              lineHeight: CodeEditorConstants.lineHeight,
              lineNumberWidth: editorService.scrollService.lineNumberWidth,
              firstVisibleLine: firstVisibleLine,
              visibleLineCount: visibleLineCount,
              zoomLevel: widget.zoomLevel,
              textStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              foldingRegions: foldingRegions,
              onFoldingToggle: _toggleFolding,
              isLineVisible: _isLineVisible,
            ),
          ),
        ),
      ),
    );
  }

  bool _isLineVisible(int line) {
    for (var region in foldingRegions) {
      if (region.isFolded &&
          line > region.startLine &&
          line <= region.endLine) {
        return false;
      }
    }
    return true;
  }

  void _toggleFolding(FoldingRegion region) {
    setState(() {
      region.isFolded = !region.isFolded;
      if (region.isFolded) {
        _updateNestedFoldingRegions(region, true);
      } else {
        _updateNestedFoldingRegions(region, false);
      }
    });

    repaintNotifier.value = !repaintNotifier.value;
    _updateVisibleLineCount();
  }

  void _updateNestedFoldingRegions(FoldingRegion parentRegion, bool isFolded) {
    for (var nestedRegion in foldingRegions) {
      if (nestedRegion.startLine > parentRegion.startLine &&
          nestedRegion.endLine <= parentRegion.endLine) {
        if (isFolded) {
          // When folding, hide all nested regions
          nestedRegion.isFolded = true;
          nestedRegion.isHidden = true;
        } else {
          // When unfolding, restore previous state of nested regions
          nestedRegion.isHidden = false;
        }
      }
    }
  }

  void _updateScrollPosition() {
    // Ensure the scroll controller has clients
    if (!editorService.scrollService.codeScrollController.hasClients) return;

    // Ensure foldingRegions is not empty
    if (foldingRegions.isEmpty) {
      return; // No need to scroll if there are no folded regions
    }

    int visibleLine = 0;
    int actualLine = 0;
    double scrollOffset = 0.0;

    // Iterate through lines to calculate scroll offset
    while (actualLine < editingCore.lineCount) {
      if (visibleLine >= firstVisibleLine) break;

      // Check for folded regions in the current line
      final foldedRegion = foldingRegions.firstWhere(
        (region) => region.isFolded && region.startLine == actualLine,
        orElse: () => FoldingRegion(
            startLine: -1, endLine: -1, startColumn: -1, endColumn: -1),
      );

      if (foldedRegion.startLine != -1) {
        // Skip folded lines
        actualLine = foldedRegion.endLine + 1;
        scrollOffset += CodeEditorConstants.lineHeight * widget.zoomLevel;
      } else {
        // Move to next line
        actualLine++;
        scrollOffset += CodeEditorConstants.lineHeight * widget.zoomLevel;
      }

      visibleLine++;
    }

    // Ensure the widget is still mounted before updating scroll
    if (mounted) {
      editorService.scrollService.codeScrollController.jumpTo(scrollOffset);
    }
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
      if (_showingSuggestions) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _selectNextSuggestion();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _selectPreviousSuggestion();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _applySelectedSuggestion();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          _hideCompletionsList();
          return KeyEventResult.handled;
        }
      }

      // Set the backspacing flag
      _isBackspacing = event.logicalKey == LogicalKeyboardKey.backspace;

      // Handle regular typing and other key events
      if (keyboardHandlingService.handleKeyPress(event)) {
        editorService.scrollService.ensureCursorVisibility();
        if (!_shouldPreventCompletions(event)) {
          _onTextChangedForSuggestions();
        } else {
          _hideCompletionsList();
        }
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      // Reset the backspacing flag on key up
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _isBackspacing = false;
      }
    }

    // Allow default behavior for unhandled keys
    return KeyEventResult.ignored;
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

    // Update the last completion position
    _lastCompletionPosition = startPosition + insertText.length;

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
  }

  bool _shouldPreventCompletions(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.tab ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.backspace;
  }

  void _onTextChangedForSuggestions() async {
    _suggestionsTimer?.cancel();
    _suggestionsTimer = Timer(const Duration(milliseconds: 50), () {
      final currentChar = _getCurrentChar();
      if (currentChar == ' ' || currentChar == '\n' || _isBackspacing) {
        _hideCompletionsList();
      } else if (_shouldShowSuggestions()) {
        if (mounted) {
          _showSuggestions();
        }
      }
    });
  }

  bool _shouldShowSuggestions() {
    if (_isBackspacing) {
      return false;
    }

    final cursorPosition = editingCore.cursorPosition;

    // Check if we've moved past the last completion position
    if (cursorPosition > _lastCompletionPosition) {
      return true;
    }

    // Check if we've moved to a different line
    final currentLine = _getLineForPosition(cursorPosition);
    final lastCompletionLine = _getLineForPosition(_lastCompletionPosition);
    if (currentLine != lastCompletionLine) {
      return true;
    }

    // Don't show suggestions if we're still at or before the last completion position
    return false;
  }

  String _getCurrentChar() {
    final cursorPosition = editingCore.cursorPosition;
    if (cursorPosition > 0 && cursorPosition <= editingCore.getText().length) {
      return editingCore.getText()[cursorPosition - 1];
    }
    return '';
  }

  void _showSuggestions() async {
    final cursorPosition = editingCore.cursorPosition;
    final line = _getLineForPosition(cursorPosition);
    final lineStartIndex = editingCore.getLineStartIndex(line);
    final character = cursorPosition - lineStartIndex;

    _currentWord = _getCurrentWord(line, character);
    print("Current word: '$_currentWord'"); // Debugging

    try {
      _completions = await getCompletions(line, character);
      print("Fetched ${_completions.length} completions:"); // Debugging
      for (var completion in _completions) {
        print("  Label: ${completion.label}");
        if (completion.detail != null) print("  Detail: ${completion.detail}");
      }
    } catch (e) {
      print("Error fetching completions: $e");
      _completions = _getFallbackCompletions();
    }

    _filterCompletions();
    print("After filtering: ${_completions.length} completions"); // Debugging

    setState(() {
      _showingSuggestions = _completions.isNotEmpty;
      _selectedSuggestionIndex = 0;
    });

    print("Showing suggestions: $_showingSuggestions"); // Debugging
  }

  void _filterCompletions() {
    if (_currentWord.isNotEmpty) {
      final lowercaseWord = _currentWord.toLowerCase();
      print("Filtering completions for word: '$lowercaseWord'"); // Debugging

      // First, add matching Dart keywords
      List<CompletionItem> keywordCompletions = _dartKeywords
          .where((keyword) => keyword.toLowerCase().startsWith(lowercaseWord))
          .map((keyword) =>
              CompletionItem(label: keyword, detail: "Dart keyword"))
          .toList();

      // Then, add other completions
      List<CompletionItem> otherCompletions = _completions.where((completion) {
        final lowercaseLabel = completion.label.toLowerCase();
        final parts = lowercaseLabel.split('/');
        bool matches = parts.any((part) => part.startsWith(lowercaseWord));

        if (lowercaseLabel.startsWith('package:')) {
          final packageName = parts.length > 1 ? parts[1] : '';
          matches = matches || packageName.startsWith(lowercaseWord);
        }

        return matches;
      }).toList();

      // Combine keyword completions and other completions
      _completions = [...keywordCompletions, ...otherCompletions];

      // Sort completions
      _completions.sort((a, b) {
        // Prioritize exact matches
        if (a.label.toLowerCase() == lowercaseWord) return -1;
        if (b.label.toLowerCase() == lowercaseWord) return 1;

        // Then prioritize starts with
        if (a.label.toLowerCase().startsWith(lowercaseWord) &&
            !b.label.toLowerCase().startsWith(lowercaseWord)) return -1;
        if (b.label.toLowerCase().startsWith(lowercaseWord) &&
            !a.label.toLowerCase().startsWith(lowercaseWord)) return 1;

        // Then sort alphabetically
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    }
    print(
        "Filtered completions: ${_completions.map((c) => c.label).join(', ')}"); // Debugging
  }

  List<CompletionItem> _getFallbackCompletions() {
    return _dartKeywords
        .map(
            (keyword) => CompletionItem(label: keyword, detail: "Dart keyword"))
        .toList();
  }

  String _getCurrentWord(int line, int character) {
    final lineText = editingCore.getLineContent(line);
    int end = character;
    int start = end - 1;

    // Move start to the beginning of the word
    while (start >= 0 && _isValidIdentifierChar(lineText[start])) {
      start--;
    }
    start++; // Adjust because we've gone one character too far

    // Move end to the end of the word
    while (end < lineText.length && _isValidIdentifierChar(lineText[end])) {
      end++;
    }

    String word = lineText.substring(start, end);
    print(
        "getCurrentWord: line=$line, character=$character, word='$word'"); // Debugging
    return word;
  }

  bool _isValidIdentifierChar(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  bool _hasNonSpaceBeforeCaret(int line, int character) {
    if (character == 0) return false;
    final lineText = editingCore.getLineContent(line);
    return character > 0 && lineText[character - 1].trim().isNotEmpty;
  }

  void _selectNextSuggestion() {
    setState(() {
      _selectedSuggestionIndex =
          (_selectedSuggestionIndex + 1) % _completions.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedSuggestion();
      });
    });
  }

  void _selectPreviousSuggestion() {
    setState(() {
      _selectedSuggestionIndex =
          (_selectedSuggestionIndex - 1 + _completions.length) %
              _completions.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedSuggestion();
      });
    });
  }

  void _scrollToSelectedSuggestion() {
    if (!_completionsScrollController.hasClients) {
      return;
    }

    final itemPosition = _selectedSuggestionIndex * kCompletionItemHeight;
    final listHeight =
        min(_completions.length, kMaxVisibleItems) * kCompletionItemHeight;

    if (itemPosition < _completionsScrollController.offset) {
      _completionsScrollController.jumpTo(itemPosition);
    } else if (itemPosition + kCompletionItemHeight >
        _completionsScrollController.offset + listHeight) {
      _completionsScrollController
          .jumpTo(itemPosition + kCompletionItemHeight - listHeight);
    }
  }

  void _applySelectedSuggestion() {
    if (_completions.isNotEmpty) {
      _applyCompletion(_completions[_selectedSuggestionIndex]);
    }
  }

  void _hideCompletionsList() {
    setState(() {
      _showingSuggestions = false;
    });
  }

  Offset _calculateCompletionPosition(int line, int character) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final editorOffset = renderBox.localToGlobal(Offset.zero);
      final scrollOffset =
          editorService.scrollService.codeScrollController.offset;
      final horizontalScrollOffset =
          editorService.scrollService.horizontalController.offset;

      final cursorX =
          (character * CodeEditorConstants.charWidth * widget.zoomLevel) -
              horizontalScrollOffset +
              editorService.scrollService.lineNumberWidth * widget.zoomLevel;
      final cursorY =
          (line * CodeEditorConstants.lineHeight * widget.zoomLevel) -
              scrollOffset;

      final adjustedY =
          cursorY + CodeEditorConstants.lineHeight * widget.zoomLevel;

      final screenSize = MediaQuery.of(context).size;
      final maxX = screenSize.width - 200;
      final maxY = screenSize.height - 300;

      return Offset(
        min(editorOffset.dx + cursorX, maxX) - 250,
        min(editorOffset.dy + adjustedY, maxY) - 118,
      );
    }
    print("RenderBox is null, cannot calculate completion position");
    return Offset.zero;
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

  int _getCharacterForPosition(int position) {
    final line = _getLineForPosition(position);
    final lineStartIndex = editingCore.getLineStartIndex(line);
    return position - lineStartIndex;
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

        _updateFoldingRegions();
      } catch (e, stackTrace) {
        print('Error loading file: $e');
        print("Stack trace: $stackTrace");
      }
    }
  }

  Future<void> _updateSemanticTokens() async {
    try {
      await _lspClient.initialized;
      await _syntaxHighlighter
          .updateSemanticTokens('file://${widget.filePath}');
      setState(() {});
    } catch (e) {
      print("Error updating semantic tokens: $e");
    }
  }

  void _onTextChanged() {
    print("Text changed. New version: ${editingCore.version}");
    if (_lastKnownVersion != editingCore.version) {
      _syntaxHighlighter.updateLine(
          editingCore.lastModifiedLine, editingCore.version);

      // Update folding regions immediately
      _updateFoldingRegions();

      setState(() {});
      widget.onContentChanged(editingCore.getText());

      // Use a microtask to ensure the UI is updated before recalculating
      Future.microtask(() {
        _recalculateEditor();
        _updateScrollPosition();
        widget.focusNode.requestFocus();
      });

      _lastKnownVersion = editingCore.version;
      _sendDocumentChanges();
      _updateSemanticTokens();
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
        'context': {'triggerKind': 1} // Invoked
      }).timeout(const Duration(seconds: 2));

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
    int visibleLines = 0;
    for (int i = 0; i < editingCore.lineCount; i++) {
      // Skip folded regions
      final foldedRegion = foldingRegions.firstWhere(
        (region) =>
            region.isFolded && i >= region.startLine && i <= region.endLine,
        orElse: () => FoldingRegion(
            startLine: -1, endLine: -1, startColumn: -1, endColumn: -1),
      );

      if (foldedRegion.startLine != -1) {
        // Skip to the end of the folded region
        i = foldedRegion.endLine;
        continue;
      }

      visibleLines++;
    }

    visibleLineCount = visibleLines;
    setState(() {}); // Repaint editor with new visible line count
  }

  void forceRedraw() {
    setState(() {
      repaintNotifier.value = !repaintNotifier.value;
    });
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
